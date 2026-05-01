import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:http/http.dart' as http;

class SampleNavigationApp extends StatefulWidget {
  const SampleNavigationApp({super.key});

  @override
  State<SampleNavigationApp> createState() => _SampleNavigationAppState();
}

class _SampleNavigationAppState extends State<SampleNavigationApp> {
  // Existing navigation variables
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

  // New sliding panel variables
  PanelController _panelController = PanelController();
  double _panelHeightOpen = 0;
  double _panelHeightClosed = 150.0; // Shows top 2 places when collapsed
  List<Place> _nearbyPlaces = [];
  List<Place> _searchResults = [];
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  // User's current location (will be updated from navigation controller)
  double _currentLat = 37.77440680146262;
  double _currentLng = -122.43539772352648;

  @override
  void initState() {
    super.initState();
    initialize();
    _fetchNearbyPlaces();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _searchController.dispose();
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

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  // Fetch nearby places using MapBox API
  Future<void> _fetchNearbyPlaces() async {
    setState(() => _isLoading = true);
    
    // MapBox Places API endpoint for nearby search
    // Using the current location (San Francisco area for demo)
    String url = "https://api.mapbox.com/geocoding/v5/mapbox.places/"
        "restaurant.json?proximity=$_currentLng,$_currentLat&limit=10&access_token=YOUR_MAPBOX_TOKEN";
    
    // Note: Replace YOUR_MAPBOX_TOKEN with your actual token
    // Since you said token is already configured, use the same one as your navigation
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Place> places = [];
        for (var feature in data['features']) {
          places.add(Place.fromJson(feature));
        }
        setState(() {
          _nearbyPlaces = places;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching places: $e");
      setState(() => _isLoading = false);
    }
  }

  // Search places using MapBox Autocomplete
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    setState(() => _isLoading = true);
    
    String url = "https://api.mapbox.com/geocoding/v5/mapbox.places/"
        "$query.json?proximity=$_currentLng,$_currentLat&limit=10&access_token=pk.eyJ1IjoiZnJlZGp5IiwiYSI6ImNtbmphZ2tiMDBnMjQycnFyNnh0cXF0cmYifQ.eubs9uIGOVmbyfXJakLo9g";
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Place> places = [];
        for (var feature in data['features']) {
          places.add(Place.fromJson(feature));
        }
        setState(() {
          _searchResults = places;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error searching: $e");
      setState(() => _isLoading = false);
    }
  }

  // Get driving distance and time between two points
  Future<Map<String, dynamic>> _getDrivingDistance(double fromLat, double fromLng, double toLat, double toLng) async {
    String url = "https://api.mapbox.com/directions/v5/mapbox/driving/"
        "$fromLng,$fromLat;$toLng,$toLat?access_token=YOUR_MAPBOX_TOKEN";
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final distance = route['distance'] / 1000; // in kilometers
        final duration = route['duration'] / 60; // in minutes
        return {'distance': distance, 'duration': duration};
      }
    } catch (e) {
      print("Error getting distance: $e");
    }
    return {'distance': 0, 'duration': 0};
  }

  // Add place as waypoint
  Future<void> _addAsWaypoint(Place place) async {
    final waypoint = WayPoint(
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      isSilent: false,
    );
    
    // Add to current route if navigation is active
    if (_routeBuilt || _isNavigating) {
      await MapBoxNavigation.instance.addWayPoints(wayPoints: [waypoint]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${place.name} as waypoint')),
      );
    }
    
    // Close the panel
    await _panelController.close();
  }

  // Show place details page
  void _showPlaceDetails(Place place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceDetailsSheet(place: place, onAdd: () => _addAsWaypoint(place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _panelHeightOpen = MediaQuery.of(context).size.height * 0.8;
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Navigation App'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            // Map View
            Container(
              color: Colors.grey,
              child: MapBoxNavigationView(
                options: _navigationOption,
                onRouteEvent: _onEmbeddedRouteEvent,
                onCreated: (MapBoxNavigationViewController controller) async {
                  _controller = controller;
                  controller.initialize();
                },
              ),
            ),
            
            // Sliding Panel
            SlidingUpPanel(
              controller: _panelController,
              maxHeight: _panelHeightOpen,
              minHeight: _panelHeightClosed,
              parallaxEnabled: true,
              parallaxOffset: 0.5,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24.0),
                topRight: Radius.circular(24.0),
              ),
              onPanelSlide: (double pos) => setState(() {}),
              panel: _buildPanelContent(),
              body: Container(), // Empty body since we're using Stack
            ),
            
            // Navigation instructions overlay (small banner)
            if (_instruction != null)
              Positioned(
                top: 80,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _instruction!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _searchPlaces,
                onTap: () {
                  setState(() => _isSearching = true);
                  _panelController.open();
                },
                decoration: InputDecoration(
                  hintText: 'Search for places...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _isSearching = false;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          
          // Content (Nearby Places or Search Results)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSearching
                    ? _buildSearchResults()
                    : _buildNearbyPlaces(),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPlaces() {
    if (_nearbyPlaces.isEmpty) {
      return const Center(child: Text('No nearby places found'));
    }
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Nearby Places',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // Show top 2 places in collapsed view, all when expanded
        ...(_panelController.isPanelOpen
            ? _nearbyPlaces.map((place) => _buildPlaceCard(place))
            : _nearbyPlaces.take(2).map((place) => _buildPlaceCard(place))),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text('No results found'));
    }
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: _searchResults.map((place) => _buildPlaceCard(place)).toList(),
    );
  }

  Widget _buildPlaceCard(Place place) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showPlaceDetails(place),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: place.imageUrl != null
                    ? Image.network(
                        place.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, size: 40),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.place, size: 40),
                      ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          place.distance != null 
                              ? '${place.distance!.toStringAsFixed(1)} km'
                              : 'Distance unknown',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          place.duration != null
                              ? '${place.duration!.toStringAsFixed(0)} min'
                              : 'ETA unknown',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => _addAsWaypoint(place),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(60, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Add', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onEmbeddedRouteEvent(e) async {
    _distanceRemaining = await MapBoxNavigation.instance.getDistanceRemaining();
    _durationRemaining = await MapBoxNavigation.instance.getDurationRemaining();

    // Update current location if available
    final location = await MapBoxNavigation.instance.getCurrentLocation();
    if (location != null) {
      _currentLat = location.latitude;
      _currentLng = location.longitude;
    }

    switch (e.eventType) {
      case MapBoxEvent.progress_change:
        var progressEvent = e.data as RouteProgressEvent;
        if (progressEvent.currentStepInstruction != null) {
          setState(() {
            _instruction = progressEvent.currentStepInstruction;
          });
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

// Place Model
class Place {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  double? distance;
  double? duration;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.distance,
    this.duration,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    final coordinates = json['geometry']['coordinates'];
    return Place(
      id: json['id'],
      name: json['text'] ?? json['place_name'] ?? 'Unknown',
      address: json['place_name'] ?? 'No address',
      latitude: coordinates[1],
      longitude: coordinates[0],
      imageUrl: json['properties']?['image_url'], // Placeholder for images
    );
  }
}

// Place Details Bottom Sheet
class PlaceDetailsSheet extends StatefulWidget {
  final Place place;
  final VoidCallback onAdd;

  const PlaceDetailsSheet({required this.place, required this.onAdd, super.key});

  @override
  State<PlaceDetailsSheet> createState() => _PlaceDetailsSheetState();
}

class _PlaceDetailsSheetState extends State<PlaceDetailsSheet> {
  List<String> demoImages = [
    'https://via.placeholder.com/400x200?text=Image+1',
    'https://via.placeholder.com/400x200?text=Image+2',
    'https://via.placeholder.com/400x200?text=Image+3',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Image slideshow
          SizedBox(
            height: 200,
            child: PageView.builder(
              itemCount: demoImages.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  child: Image.network(
                    demoImages[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, size: 50),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Place details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.place.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.place.address,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onAdd();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add to Route'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
