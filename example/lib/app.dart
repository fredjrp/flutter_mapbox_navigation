import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:http/http.dart' as http;
import 'location_product_page.dart';

const String MAPBOX_ACCESS_TOKEN = String.fromEnvironment(
  'MAPBOX_ACCESS_TOKEN',
  defaultValue: 'pk.eyJ1IjoiZnJlZGp5IiwiYSI6ImNtbmphZ2tiMDBnMjQycnFyNnh0cXF0cmYifQ.eubs9uIGOVmbyfXJakLo9g'
);

class SampleNavigationApp extends StatefulWidget {
  const SampleNavigationApp({super.key});

  @override
  State<SampleNavigationApp> createState() => _SampleNavigationAppState();
}

class _SampleNavigationAppState extends State<SampleNavigationApp> {
  String? _platformVersion;
  String? _instruction;
  
  WayPoint? _destination;
  
  final _mockDeviceLocation = WayPoint(
      name: "Rongai, Kenya",
      latitude: -1.396,
      longitude: 36.762,
      isSilent: false);

  bool _isMultipleStop = false;
  double? _distanceRemaining, _durationRemaining;
  MapBoxNavigationViewController? _controller;
  bool _routeBuilt = false;
  bool _isNavigating = false;
  bool _inFreeDrive = false;
  late MapBoxOptions _navigationOption;
  
  TextEditingController _searchController = TextEditingController();
  final PanelController _panelController = PanelController();
  
  // Floating Card Data
  String? _selectedLocationName;
  String? _selectedLocationAddress;
  String? _selectedLocationImageUrl;
  bool _isLocationCardVisible = false;

  // Embedded Search Suggestions
  List<Map<String, dynamic>> _suggestions = [];

  // Route Cart (now holds maps with waypoint and priority)
  List<Map<String, dynamic>> _routeCart = [];
  bool _autoStartNavigation = false;

  @override
  void initState() {
    super.initState();
    if (_destination?.name != null) {
      _searchController.text = _destination!.name!;
    }
    initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller?.dispose();
    super.dispose();
  }

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

  // ==== MAPBOX API INTEGRATIONS ====

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    
    // Expand panel slightly so user can see suggestions
    if (_panelController.isAttached && _panelController.panelPosition < 0.5) {
      _panelController.animatePanelToPosition(0.6);
    }

    final url = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$MAPBOX_ACCESS_TOKEN&autocomplete=true&limit=3');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        setState(() {
          _suggestions = features.map((f) => {
            'place_name': f['place_name'],
            'text': f['text'],
            'center': f['center'], // [longitude, latitude]
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching suggestions: $e");
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$MAPBOX_ACCESS_TOKEN&limit=1');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          final feature = features[0];
          _updateLocationDetails(
            name: feature['text'] ?? "Pinned Location",
            address: feature['place_name'] ?? "",
            lat: lat,
            lng: lng,
          );
        }
      }
    } catch (e) {
      debugPrint("Error reverse geocoding: $e");
    }
  }

  void _updateLocationDetails({required String name, required String address, required double lat, required double lng}) {
    setState(() {
      _selectedLocationName = name;
      _selectedLocationAddress = address;
      _destination = WayPoint(name: name, latitude: lat, longitude: lng, isSilent: false);
      
      _searchController.text = name;
      _suggestions.clear();
      
      // Minimize panel to interact with card
      if (_panelController.isAttached) {
        _panelController.close();
      }
      
      // Generate static map image URL
      _selectedLocationImageUrl = 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/static/pin-s-marker+285A98($lng,$lat)/$lng,$lat,14,0/400x400?access_token=$MAPBOX_ACCESS_TOKEN';
      _isLocationCardVisible = true;
    });
    
    // Auto-build route to new location (for visual preview)
    _buildRoute(clearFirst: true);
  }

  // ==== UI BUILDING ====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SlidingUpPanel(
        controller: _panelController,
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
        body: Stack(
          children: [
            _buildMap(),
            _buildLocationCard(),
          ],
        ),
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

  Widget _buildLocationCard() {
    if (!_isLocationCardVisible) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 140.0, left: 16.0, right: 16.0),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Card(
            elevation: 8,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Main Proceed Area (Left)
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () async {
                        final addedPointMap = await Navigator.of(context).push<Map<String, dynamic>>(
                          MaterialPageRoute(
                            builder: (_) => LocationProductPage(
                              location: _destination!,
                              address: _selectedLocationAddress,
                              imageUrl: _selectedLocationImageUrl,
                            ),
                          ),
                        );
                        if (addedPointMap != null) {
                          setState(() {
                            _routeCart.add(addedPointMap);
                            // Keep card visible to show checkout button
                          });
                        }
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left: Mapbox Image
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                            child: _selectedLocationImageUrl != null 
                              ? Image.network(
                                  _selectedLocationImageUrl!,
                                  width: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 100,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                  ),
                                )
                              : Container(width: 100, color: Colors.grey[200]),
                          ),
                          // Right: Description
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedLocationName ?? "Unknown Location",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          iconSize: 20,
                                          icon: const Icon(Icons.close, color: Colors.grey),
                                          onPressed: () => setState(() => _isLocationCardVisible = false),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedLocationAddress ?? "",
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Checkout Area (Right)
                  if (_routeCart.isNotEmpty)
                    Container(
                      width: 1,
                      color: Colors.grey[300],
                    ),
                  if (_routeCart.isNotEmpty)
                    Expanded(
                      flex: 1,
                      child: Material(
                        color: Colors.black87,
                        child: InkWell(
                          onTap: _startCartNavigation,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.route, color: Colors.white),
                                const SizedBox(height: 4),
                                Text(
                                  "Checkout\n(${_routeCart.length})",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
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
        // Embedded Search Bar
        _buildSearchBar(),
        
        // Embedded Suggestions List
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: _suggestions.map((suggestion) {
                return ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.blue),
                  title: Text(suggestion['text'] ?? "", style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(suggestion['place_name'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    final center = suggestion['center'] as List;
                    _updateLocationDetails(
                      name: suggestion['text'],
                      address: suggestion['place_name'],
                      lng: center[0],
                      lat: center[1],
                    );
                  },
                );
              }).toList(),
            ),
          ),
          
        const SizedBox(height: 8.0),
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

                // Navigation Status
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonal(
                      onPressed: _isNavigating ? null : () => _buildRoute(clearFirst: false),
                      child: Text(_routeBuilt && !_isNavigating
                          ? "Clear Route"
                          : "Preview Route"),
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
                    "Tap Map to Set Destination",
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: Colors.grey[300]!),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  _fetchSuggestions(val);
                },
                decoration: const InputDecoration(
                  hintText: "Where to?",
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _suggestions.clear());
                },
              ),
          ],
        ),
      ),
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

  Future<void> _startCartNavigation() async {
    // Sort descending by priority (High: 2, Med: 1, Low: 0)
    // Low priority ends up at the end of the array (final destination)
    _routeCart.sort((a, b) => (b['priority'] as int).compareTo(a['priority'] as int));

    var wayPoints = <WayPoint>[];
    wayPoints.add(_mockDeviceLocation); // Dynamic origin instead of hardcoded _home
    for (var item in _routeCart) {
      wayPoints.add(item['waypoint'] as WayPoint);
    }
    
    _isMultipleStop = wayPoints.length > 2;
    
    // Minimize panel to let user see the navigation fully
    if (_panelController.isAttached) {
      _panelController.close();
    }
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Building Route..."), duration: Duration(seconds: 1)),
    );

    try {
      // Wait for the route to build
      final success = await _controller?.buildRoute(wayPoints: wayPoints, options: _navigationOption);
      
      if (success == true) {
        // Explicitly start embedded navigation after successful build
        await _controller?.startNavigation(options: _navigationOption);
        
        setState(() {
          _routeCart.clear();
          _isLocationCardVisible = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to build route. Make sure locations are reachable by car.")),
        );
      }
    } catch (e) {
      debugPrint("Error starting navigation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _buildRoute({bool clearFirst = false}) {
    if (clearFirst) {
      _controller?.clearRoute();
      _routeBuilt = false;
    }
    
    if (_routeBuilt && !clearFirst) {
      _controller?.clearRoute();
      setState(() {
        _routeBuilt = false;
      });
    } else {
      var wayPoints = <WayPoint>[];
      wayPoints.add(_mockDeviceLocation);
      if (_destination != null) {
        wayPoints.add(_destination!);
      }
      
      if (wayPoints.length >= 2) {
        _isMultipleStop = wayPoints.length > 2;
        _controller?.buildRoute(
            wayPoints: wayPoints, options: _navigationOption);
      }
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
      case MapBoxEvent.on_map_tap:
        if (e.data is WayPoint) {
          final wp = e.data as WayPoint;
          if (wp.latitude != null && wp.longitude != null) {
            _reverseGeocode(wp.latitude!, wp.longitude!);
          }
        }
        break;
      default:
        break;
    }
    setState(() {});
  }
}
