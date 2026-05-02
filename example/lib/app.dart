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
  final PanelController _panelController = PanelController();

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _panelController.dispose();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initialize() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    _navigationOption = MapBoxNavigation.instance.getDefaultOptions();
    _navigationOption.simulateRoute = true;
    _navigationOption.language = "en";
    //_navigationOption.initialLatitude = 36.1175275;
    //_navigationOption.initialLongitude = -115.1839524;
    MapBoxNavigation.instance.registerRouteEventListener(_onEmbeddedRouteEvent);

    String? platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await MapBoxNavigation.instance.getPlatformVersion();
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Navigation with Sliding Panel'),
        ),
        body: SlidingUpPanel(
          controller: _panelController,
          minHeight: 120, // Height when collapsed
          maxHeight: MediaQuery.of(context).size.height * 0.45, // Height when expanded
          parallaxEnabled: true,
          parallaxOffset: 0.5,
          panel: _buildControlPanel(),
          body: _buildMapStack(),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
        ),
      ),
    );
  }

  // Separate the Map and buttons to keep the build method clean
  Widget _buildMapStack() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: MapBoxNavigationView(
                options: _navigationOption,
                onRouteEvent: _onEmbeddedRouteEvent,
                onCreated: (MapBoxNavigationViewController controller) async {
                  _controller = controller;
                  controller.initialize();
                },
              ),
            ),
            const SizedBox(height: 120), // Space for the collapsed panel
          ],
        ),
        // Floating action buttons overlay on the map
        Positioned(
          bottom: 130,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingButton(
                icon: Icons.my_location,
                onPressed: () {
                  // Center on user location if needed
                },
              ),
              const SizedBox(height: 8),
              _buildFloatingButton(
                icon: _panelController.isPanelOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                onPressed: () {
                  if (_panelController.isPanelOpen) {
                    _panelController.close();
                  } else {
                    _panelController.open();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(30),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          minimumSize: const Size(48, 48),
        ),
      ),
    );
  }

  // This is the content inside the sliding panel
  Widget _buildControlPanel() {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Pull handle
        Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Instruction banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _instruction ?? "Slide up for navigation details",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        const Divider(height: 24),
        // Duration and Distance info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoColumn("Duration Remaining", _durationRemaining != null 
                  ? "${(_durationRemaining! / 60).toStringAsFixed(0)} min" 
                  : "---"),
              _infoColumn("Distance Remaining", _distanceRemaining != null 
                  ? "${(_distanceRemaining! * 0.000621371).toStringAsFixed(1)} miles" 
                  : "---"),
            ],
          ),
        ),
        const Divider(height: 24),
        // Navigation buttons
        _buildNavigationButtons(),
        const SizedBox(height: 16),
        // Additional info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Long-Press Embedded Map to Set Destination",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        // Full Screen Navigation Section
        _buildSectionTitle("Full Screen Navigation"),
        const SizedBox(width: 10),
        ElevatedButton(
          child: const Text("Start A to B"),
          onPressed: () async {
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
          },
        ),
        ElevatedButton(
          child: const Text("Start Multi Stop"),
          onPressed: () async {
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
            await Future.delayed(const Duration(seconds: 10));
            var stop = WayPoint(
                name: "Gas Station",
                latitude: 38.911176544398,
                longitude: -77.04014366543564,
                isSilent: false);
            MapBoxNavigation.instance
                .addWayPoints(wayPoints: [stop]);
          },
        ),
        ElevatedButton(
          child: const Text("Free Drive"),
          onPressed: () async {
            await MapBoxNavigation.instance.startFreeDrive();
          },
        ),
        
        _buildSectionTitle("Embedded Navigation"),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _isNavigating
              ? null
              : () {
                  if (_routeBuilt) {
                    _controller?.clearRoute();
                    setState(() {
                      _routeBuilt = false;
                    });
                  } else {
                    var wayPoints = <WayPoint>[];
                    wayPoints.add(_home);
                    wayPoints.add(_store);
                    _isMultipleStop = wayPoints.length > 2;
                    _controller?.buildRoute(
                        wayPoints: wayPoints,
                        options: _navigationOption);
                  }
                },
          child: Text(_routeBuilt && !_isNavigating
              ? "Clear Route"
              : "Build Route"),
        ),
        ElevatedButton(
          onPressed: _routeBuilt && !_isNavigating
              ? () {
                  _controller?.startNavigation();
                }
              : null,
          child: const Text('Start Navigation'),
        ),
        ElevatedButton(
          onPressed: _isNavigating
              ? () {
                  _controller?.finishNavigation();
                }
              : null,
          child: const Text('Cancel Navigation'),
        ),
        ElevatedButton(
          onPressed: _inFreeDrive
              ? null
              : () async {
                  _inFreeDrive =
                      await _controller?.startFreeDrive() ?? false;
                  setState(() {});
                },
          child: const Text("Free Drive Embedded"),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
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
        } else {}
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
