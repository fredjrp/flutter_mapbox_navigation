import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:http/http.dart' as http;
import 'location_product_page.dart';
import 'cart_list_page.dart';

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

  Future<void> _openCartList() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CartListPage(initialCart: _routeCart),
      ),
    );

    if (result != null) {
      setState(() {
        _routeCart = List<Map<String, dynamic>>.from(result['cart']);
      });

      if (result['action'] == 'checkout') {
        _startCartNavigation();
      }
    }
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _openCartList,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.shopping_cart, color: Colors.white, size: 18),
                                      const SizedBox(height: 2),
                                      Text("Cart (${_routeCart.length})",
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(height: 1, color: Colors.white24),
                            Expanded(
                              child: InkWell(
                                onTap: _startCartNavigation,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.navigation, color: Colors.white, size: 18),
                                      SizedBox(height: 2),
                                      Text("Checkout",
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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

                // Recommended Products
                _buildProductList(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductList() {
    final List<Map<String, String>> products = [
      {
        "title": "Havit PB50 27000mAh Power Bank",
        "description": "140W PD3.1 Ultra Fast Charging Portable Charger with Smart LED Display",
        "imageUrl": "https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80",
        "url": "https://www.jumia.co.ke/havit-pb50-27000mah-10000mah-80000mh-power-bank-powerbank-140w-pd3.1-ultra-fast-charging-portable-charger-smart-led-display-with-3-port-output-airline-approved-external-battery-for-macbook-pro-laptops-laptop-iphone-1516-and-samsung-galaxy-327339191"
      },
      {
        "title": "Kuhl K2 20000mAh Power Bank",
        "description": "High Capacity Portable Charger for Phones & USB Devices",
        "imageUrl": "https://images.unsplash.com/photo-1620189507195-68309c04c4d0?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80",
        "url": "https://www.jumia.co.ke/kuhl-kuhl-k2-20000mah-power-bank-high-capacity-portable-charger-for-phones-usb-devices-326556308"
      },
      {
        "title": "Vention 20000mAh Power Bank",
        "description": "Phone/Laptop Power Bank 100W FKCH0",
        "imageUrl": "https://images.unsplash.com/photo-1585338107529-13afc5f02586?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80",
        "url": "https://www.jumia.co.ke/vention-20000mah-phone-laptop-power-bank-100w-fkch0.-325999720"
      }
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            "Recommended Products",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        ...products.map((product) {
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                // Future: Navigate to product detail or open url
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Tapped ${product['title']}")),
                );
              },
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                      child: Image.network(
                        product['imageUrl']!,
                        width: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          color: Colors.grey[200],
                          child: const Icon(Icons.battery_charging_full, color: Colors.grey),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              product['title']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              product['description']!,
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
          );
        }).toList(),
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
    String etaString = "---";
    if (_durationRemaining != null && _durationRemaining! > 0) {
      final eta = DateTime.now().add(Duration(seconds: _durationRemaining!.toInt()));
      int hour = eta.hour > 12 ? eta.hour - 12 : (eta.hour == 0 ? 12 : eta.hour);
      String ampm = eta.hour >= 12 ? "PM" : "AM";
      String minute = eta.minute.toString().padLeft(2, '0');
      etaString = "$hour:$minute $ampm";
    }

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
            _instruction ?? "Calculating Route...",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text("ETA",
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                  Text(
                    etaString,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
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
                        ? "${(_distanceRemaining! / 1000).toStringAsFixed(1)} km"
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
      // Create multi-stop specific options
      var opt = MapBoxOptions.from(_navigationOption);
      opt.mode = MapBoxNavigationMode.driving;
      opt.allowsUTurnAtWayPoints = true;
      opt.simulateRoute = true;
      opt.voiceInstructionsEnabled = true;
      opt.bannerInstructionsEnabled = true;
      opt.units = VoiceUnits.metric;
      opt.language = "en";

      // Wait for the route to build
      final success = await _controller?.buildRoute(wayPoints: wayPoints, options: opt);
      
      if (success == true) {
        // Explicitly start embedded navigation after successful build
        await _controller?.startNavigation(options: opt);
        
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
    try {
      if (_controller != null) {
        _distanceRemaining = await _controller!.distanceRemaining;
        _durationRemaining = await _controller!.durationRemaining;
      } else {
        _distanceRemaining = await MapBoxNavigation.instance.getDistanceRemaining();
        _durationRemaining = await MapBoxNavigation.instance.getDurationRemaining();
      }
    } catch (err) {
      debugPrint("Error fetching nav stats: $err");
    }

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
