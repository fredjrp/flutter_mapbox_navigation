import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import '../../models/cart_entry.dart';

class NavigationScreen extends StatefulWidget {
  final List<CartEntry> cartEntries;
  final double? userLat;
  final double? userLng;

  const NavigationScreen({
    super.key,
    required this.cartEntries,
    this.userLat,
    this.userLng,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  MapBoxNavigationViewController? _controller;
  bool _routeBuilt = false;
  bool _isNavigating = false;
  bool _arrived = false;
  double? _distanceRemaining;
  double? _durationRemaining;
  String? _instruction;
  int _currentStopIndex = 0;
  late MapBoxOptions _options;

  @override
  void initState() {
    super.initState();
    _options = MapBoxNavigation.instance.getDefaultOptions();
    _options.simulateRoute = false;
    _options.language = 'en';
    _options.voiceInstructionsEnabled = true;
    _options.bannerInstructionsEnabled = true;
    _options.units = VoiceUnits.metric;
    MapBoxNavigation.instance.registerRouteEventListener(_onRouteEvent);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<WayPoint> _buildWayPoints() {
    final points = <WayPoint>[];

    // Origin: user location or first store
    if (widget.userLat != null && widget.userLng != null) {
      points.add(WayPoint(
        name: 'My Location',
        latitude: widget.userLat!,
        longitude: widget.userLng!,
        isSilent: true,
      ));
    }

    // Add each store as a waypoint
    for (int i = 0; i < widget.cartEntries.length; i++) {
      final store = widget.cartEntries[i].store;
      points.add(WayPoint(
        name: store.name,
        latitude: store.latitude,
        longitude: store.longitude,
        // Silent for intermediate stops, speak for last stop
        isSilent: i < widget.cartEntries.length - 1,
      ));
    }
    return points;
  }

  Future<void> _buildRoute() async {
    final wayPoints = _buildWayPoints();
    await _controller?.buildRoute(
        wayPoints: wayPoints, options: _options);
  }

  Future<void> _startNavigation() async {
    await _controller?.startNavigation();
  }

  Future<void> _cancelNavigation() async {
    await _controller?.finishNavigation();
  }

  Future<void> _onRouteEvent(e) async {
    _distanceRemaining =
        await MapBoxNavigation.instance.getDistanceRemaining();
    _durationRemaining =
        await MapBoxNavigation.instance.getDurationRemaining();

    switch (e.eventType) {
      case MapBoxEvent.progress_change:
        final progress = e.data as RouteProgressEvent;
        if (progress.currentStepInstruction != null) {
          setState(() => _instruction = progress.currentStepInstruction);
        }
        break;
      case MapBoxEvent.route_building:
        break;
      case MapBoxEvent.route_built:
        setState(() => _routeBuilt = true);
        break;
      case MapBoxEvent.route_build_failed:
        setState(() => _routeBuilt = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Failed to build route. Check store coordinates.')));
        }
        break;
      case MapBoxEvent.navigation_running:
        setState(() => _isNavigating = true);
        break;
      case MapBoxEvent.on_arrival:
        _handleArrival();
        break;
      case MapBoxEvent.navigation_finished:
      case MapBoxEvent.navigation_cancelled:
        setState(() {
          _routeBuilt = false;
          _isNavigating = false;
          _arrived = false;
        });
        break;
      default:
        break;
    }
    if (mounted) setState(() {});
  }

  void _handleArrival() {
    if (_currentStopIndex < widget.cartEntries.length - 1) {
      // Not the last stop — show intermediate arrival dialog
      _currentStopIndex++;
      _showStopArrivalDialog(
          widget.cartEntries[_currentStopIndex - 1].store.name);
    } else {
      // Final destination reached
      setState(() => _arrived = true);
      _showFinalArrivalDialog();
    }
  }

  void _showStopArrivalDialog(String storeName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          const Text('Arrived!'),
        ]),
        content: Text(
            'You\'ve arrived at $storeName.\n\nCollect your items, then continue to the next stop.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Continue Navigation'),
          ),
        ],
      ),
    );
  }

  void _showFinalArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.celebration, color: Colors.orange),
          const SizedBox(width: 8),
          const Text('Trip Complete!'),
        ]),
        content: Text(
            'You\'ve collected items from all ${widget.cartEntries.length} store${widget.cartEntries.length > 1 ? 's' : ''}!'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // return to cart
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigating (${widget.cartEntries.length} stops)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (_isNavigating) await _cancelNavigation();
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Stops overview banner
          _buildStopsBanner(),
          // Current instruction banner
          if (_instruction != null)
            Container(
              color: const Color(0xFF1A73E8),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                _instruction!,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          // Map
          Expanded(
            child: MapBoxNavigationView(
              options: _options,
              onRouteEvent: _onRouteEvent,
              onCreated: (MapBoxNavigationViewController controller) {
                _controller = controller;
                controller.initialize();
              },
            ),
          ),
          // Stats
          _buildStatsBar(),
          // Action buttons
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildStopsBanner() {
    return Container(
      height: 70,
      color: Colors.grey.shade900,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: widget.cartEntries.length,
        itemBuilder: (context, i) {
          final isDone = i < _currentStopIndex;
          final isCurrent = i == _currentStopIndex && _isNavigating;
          return Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDone
                    ? Colors.green
                    : isCurrent
                        ? Colors.orange
                        : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Icon(
                  isDone
                      ? Icons.check
                      : isCurrent
                          ? Icons.navigation
                          : Icons.store,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(widget.cartEntries[i].store.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
            if (i < widget.cartEntries.length - 1)
              const Icon(Icons.chevron_right, color: Colors.grey),
          ]);
        },
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.timer_outlined, 'ETA',
              _durationRemaining != null
                  ? '${(_durationRemaining! / 60).toStringAsFixed(0)} min'
                  : '---'),
          _statItem(Icons.route, 'Distance',
              _distanceRemaining != null
                  ? '${(_distanceRemaining! / 1000).toStringAsFixed(1)} km'
                  : '---'),
          _statItem(Icons.store, 'Stops',
              '${_currentStopIndex + 1}/${widget.cartEntries.length}'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(children: [
      Icon(icon, color: const Color(0xFF1A73E8), size: 20),
      Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      child: Row(children: [
        if (!_routeBuilt && !_isNavigating)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.route),
              label: const Text('Build Route'),
              onPressed: _buildRoute,
            ),
          ),
        if (_routeBuilt && !_isNavigating) ...[
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.navigation),
              label: const Text('Start Navigation'),
              onPressed: _startNavigation,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _controller?.clearRoute(),
            child: const Text('Clear'),
          ),
        ],
        if (_isNavigating)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop Navigation'),
              onPressed: _cancelNavigation,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red),
            ),
          ),
      ]),
    );
  }
}
