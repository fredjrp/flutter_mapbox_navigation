import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class SampleNavigationApp extends StatefulWidget {
  const SampleNavigationApp({super.key});

  @override
  State<SampleNavigationApp> createState() => _SampleNavigationAppState();
}

class _SampleNavigationAppState extends State<SampleNavigationApp> {
  String? _platformVersion;
  String? _instruction;
  final _origin = WayPoint(
      name: "Way Point 1",
      latitude: 38.9111117447887,
      longitude: -77.04012393951416,
      isSilent: true);
  final _stop1 = WayPoint(
      name: "Way Point 2",
      latitude: 38.91113678979344,
      longitude: -77.03847169876099,
      isSilent: true);
  final _stop2 = WayPoint(
      name: "Way Point 3",
      latitude: 38.91040213277608,
      longitude: -77.03848242759705,
      isSilent: false);
  final _stop3 = WayPoint(
      name: "Way Point 4",
      latitude: 38.909650771013034,
      longitude: -77.03850388526917,
      isSilent: true);
  final _destination = WayPoint(
      name: "Way Point 5",
      latitude: 38.90894949285854,
      longitude: -77.03651905059814,
      isSilent: false);

  final _home = WayPoint(
      name: "Home",
      latitude: 37.77440680146262,
      longitude: -122.43539772352648,
      isSilent: false);

  final _store = WayPoint(
      name: "Store",
      latitude: 37.76556957793795,
      longitude: -122.42409811526268,
      isSilent: false);

  bool _isMultipleStop = false;
  double? _distanceRemaining, _durationRemaining;
  MapBoxNavigationViewController? _controller;
  bool _routeBuilt = false;
  bool _isNavigating = false;
  bool _inFreeDrive = false;
  late MapBoxOptions _navigationOption;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initialize() async {
    if (!mounted) return;

    _navigationOption = MapBoxNavigation.instance.getDefaultOptions();
    _navigationOption.simulateRoute = true;
    _navigationOption.language = "en";
    MapBoxNavigation.instance.registerRouteEventListener(_onEmbeddedRouteEvent);

    String? platformVersion;
    try {
      platformVersion = await MapBoxNavigation.instance.getPlatformVersion();
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (mounted) {
      setState(() {
        _platformVersion = platformVersion;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SlidingUpPanel(
        minHeight: 120.0,
        maxHeight: MediaQuery.of(context).size.height * 0.7,
        parallaxEnabled: true,
        parallaxOffset: 0.5,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10.0,
            color: Colors.black26,
          ),
        ],
        panelBuilder: (ScrollController sc) => _buildPanel(sc),
        body: _buildMap(),
      ),
    );
  }

  Widget _buildMap() {
    return MapBoxNavigationView(
      options: _navigationOption,
      onRouteEvent: _onEmbeddedRouteEvent,
      onCreated: (MapBoxNavigationViewController controller) async {
        _controller = controller;
        controller.initialize();
      },
    );
  }

  Widget _buildPanel(ScrollController sc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12.0),
        // Drag Handle
        Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // Search Bar showing destination data
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: Colors.grey[300]!),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _destination.name ?? "Where to?",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // Scrollable content inside the panel
        Expanded(
          child: SingleChildScrollView(
            controller: sc,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HUD (Visible only if there's route data)
                if (_instruction != null || _distanceRemaining != null) ...[
                  _buildHUD(),
                  const SizedBox(height: 20),
                ],

                // Full Screen Navigation Buttons
                const Text(
                  "Full Screen Navigation",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      onPressed: _startAtoB,
                      child: const Text("Start A to B"),
                    ),
                    FilledButton(
                      onPressed: _startMultiStop,
                      child: const Text("Start Multi Stop"),
                    ),
                    FilledButton(
                      onPressed: _startFreeDrive,
                      child: const Text("Free Drive"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),

                // Embedded Navigation Buttons
                const Text(
                  "Embedded Navigation",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonal(
                      onPressed: _isNavigating ? null : _buildRoute,
                      child: Text(_routeBuilt && !_isNavigating
                          ? "Clear Route"
                          : "Build Route"),
                    ),
                    FilledButton.tonal(
                      onPressed: _routeBuilt && !_isNavigating
                          ? _startEmbeddedNavigation
                          : null,
                      child: const Text('Start'),
                    ),
                    FilledButton.tonal(
                      onPressed: _isNavigating ? _cancelEmbeddedNavigation : null,
                      child: const Text('Cancel'),
                    ),
                    FilledButton.tonal(
                      onPressed: _inFreeDrive ? null : _startEmbeddedFreeDrive,
                      child: const Text("Free Drive"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    "Long-Press Map to Set Destination",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
                if (_platformVersion != null)
                  Center(
                    child: Text(
                      'Running on: $_platformVersion',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHUD() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            _instruction ?? "Banner Instruction Here",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text("Duration",
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                  Text(
                    _durationRemaining != null
                        ? "${(_durationRemaining! / 60).toStringAsFixed(0)} min"
                        : "---",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text("Distance",
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                  Text(
                    _distanceRemaining != null
                        ? "${(_distanceRemaining! * 0.000621371).toStringAsFixed(1)} mi"
                        : "---",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startAtoB() async {
    var wayPoints = <WayPoint>[];
    wayPoints.add(_home);
    wayPoints.add(_store);
    var opt = MapBoxOptions.from(_navigationOption);
    opt.simulateRoute = true;
    opt.voiceInstructionsEnabled = true;
    opt.bannerInstructionsEnabled = true;
    opt.units = VoiceUnits.metric;
    opt.language = "de-DE";
    await MapBoxNavigation.instance
        .startNavigation(wayPoints: wayPoints, options: opt);
  }

  Future<void> _startMultiStop() async {
    _isMultipleStop = true;
    var wayPoints = <WayPoint>[];
    wayPoints.add(_origin);
    wayPoints.add(_stop1);
    wayPoints.add(_stop2);
    wayPoints.add(_stop3);
    wayPoints.add(_destination);

    MapBoxNavigation.instance.startNavigation(
        wayPoints: wayPoints,
        options: MapBoxOptions(
            mode: MapBoxNavigationMode.driving,
            simulateRoute: true,
            language: "en",
            allowsUTurnAtWayPoints: true,
            units: VoiceUnits.metric));
    
    //after 10 seconds add a new stop
    await Future.delayed(const Duration(seconds: 10));
    var stop = WayPoint(
        name: "Gas Station",
        latitude: 38.911176544398,
        longitude: -77.04014366543564,
        isSilent: false);
    MapBoxNavigation.instance.addWayPoints(wayPoints: [stop]);
  }

  Future<void> _startFreeDrive() async {
    await MapBoxNavigation.instance.startFreeDrive();
  }

  void _buildRoute() {
    if (_routeBuilt) {
      _controller?.clearRoute();
    } else {
      var wayPoints = <WayPoint>[];
      wayPoints.add(_home);
      wayPoints.add(_store);
      _isMultipleStop = wayPoints.length > 2;
      _controller?.buildRoute(
          wayPoints: wayPoints, options: _navigationOption);
    }
  }

  void _startEmbeddedNavigation() {
    _controller?.startNavigation();
  }

  void _cancelEmbeddedNavigation() {
    _controller?.finishNavigation();
  }

  Future<void> _startEmbeddedFreeDrive() async {
    _inFreeDrive = await _controller?.startFreeDrive() ?? false;
    setState(() {});
  }

  Future<void> _onEmbeddedRouteEvent(e) async {
    _distanceRemaining = await MapBoxNavigation.instance.getDistanceRemaining();
    _durationRemaining = await MapBoxNavigation.instance.getDurationRemaining();

    switch (e.eventType) {
      case MapBoxEvent.progress_change:
        var progressEvent = e.data as RouteProgressEvent;
        if (progressEvent.currentStepInstruction != null) {
          _instruction = progressEvent.currentStepInstruction;
        }
        break;
      case MapBoxEvent.route_building:
      case MapBoxEvent.route_built:
        setState(() {
          _routeBuilt = true;
        });
        break;
      case MapBoxEvent.route_build_failed:
        setState(() {
          _routeBuilt = false;
        });
        break;
      case MapBoxEvent.navigation_running:
        setState(() {
          _isNavigating = true;
        });
        break;
      case MapBoxEvent.on_arrival:
        if (!_isMultipleStop) {
          await Future.delayed(const Duration(seconds: 3));
          await _controller?.finishNavigation();
        }
        break;
      case MapBoxEvent.navigation_finished:
      case MapBoxEvent.navigation_cancelled:
        setState(() {
          _routeBuilt = false;
          _isNavigating = false;
        });
        break;
      default:
        break;
    }
    setState(() {});
  }
}
