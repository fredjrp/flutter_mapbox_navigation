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

  // Sliding panel variables
  PanelController _panelController = PanelController();
  double _panelHeightOpen = 0;
  double _panelHeightClosed = 150.0;
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();
  
  // Sample nearby places data
  List<Place> _nearbyPlaces = [];
  List<Place> _searchResults = [];

  @override
  void initState() {
    super.initState();
    initialize();
    _loadSamplePlaces();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadSamplePlaces() {
    // Sample data for testing the UI
    _nearbyPlaces = [
      Place(
        id: '1',
        name: 'Starbucks Coffee',
        address: '123 Market St, San Francisco, CA',
        latitude: 37.7749,
        longitude: -122.4194,
        imageUrl: null,
        distance: 0.5,
        duration: 3,
        rating: 4.5,
        category: 'Coffee Shop',
      ),
      Place(
        id: '2',
        name: 'Whole Foods Market',
        address: '450 Main St, San Francisco, CA',
        latitude: 37.7750,
        longitude: -122.4180,
        imageUrl: null,
        distance: 0.8,
        duration: 5,
        rating: 4.2,
        category: 'Grocery',
      ),
      Place(
        id: '3',
        name: 'Planet Fitness',
        address: '789 Mission St, San Francisco, CA',
        latitude: 37.7730,
        longitude: -122.4200,
        imageUrl: null,
        distance: 1.2,
        duration: 7,
        rating: 4.0,
        category: 'Gym',
      ),
      Place(
        id: '4',
        name: 'Pizza Hut',
        address: '321 Howard St, San Francisco, CA',
        latitude: 37.7760,
        longitude: -122.4170,
        imageUrl: null,
        distance: 1.5,
        duration: 8,
        rating: 3.8,
        category: 'Restaurant',
      ),
      Place(
        id: '5',
        name: 'Walgreens Pharmacy',
        address: '567 4th St, San Francisco, CA',
        latitude: 37.7770,
        longitude: -122.4160,
        imageUrl: null,
        distance: 1.8,
        duration: 10,
        rating: 4.1,
        category: 'Pharmacy',
      ),
    ];
    _searchResults = [];
  }

  // Simulate search functionality
  void _searchPlaces(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    setState(() {
      _searchResults = _nearbyPlaces
          .where((place) => place.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  // Add place as waypoint
  Future<void> _addAsWaypoint(Place place) async {
    final waypoint = WayPoint(
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      isSilent: false,
    );
    
    if (_routeBuilt || _isNavigating) {
      await MapBoxNavigation.instance.addWayPoints(wayPoints: [waypoint]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${place.name} as waypoint'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please build a route first before adding waypoints'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    
    await _panelController.close();
  }

  // Show place details
  void _showPlaceDetails(Place place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceDetailsSheet(
        place: place, 
        onAdd: () => _addAsWaypoint(place),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    initialize();
    _loadSamplePlaces();
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

  @override
  Widget build(BuildContext context) {
    _panelHeightOpen = MediaQuery.of(context).size.height * 0.75;
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Navigation App'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          children: [
            // Map View
            MapBoxNavigationView(
              options: _navigationOption,
              onRouteEvent: _onEmbeddedRouteEvent,
              onCreated: (MapBoxNavigationViewController controller) async {
                _controller = controller;
                controller.initialize();
              },
            ),
            
            // Navigation instruction banner (floating on top of map)
            if (_instruction != null)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.navigation, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _instruction!,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
              panel: _buildPanelContent(),
              body: Container(),
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
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey[200]!),
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
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[600]),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: _isSearching && _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildNearbyPlaces(),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPlaces() {
    if (_nearbyPlaces.isEmpty) {
      return const Center(child: Text('No places found'));
    }
    
    final displayPlaces = _panelController.isPanelOpen 
        ? _nearbyPlaces 
        : _nearbyPlaces.take(2).toList();
    
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
        ...displayPlaces.map((place) => _buildPlaceCard(place)),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
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
              // Placeholder Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: Icon(
                    _getCategoryIcon(place.category),
                    size: 40,
                    color: Colors.grey[600],
                  ),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          place.rating.toString(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.category, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          place.category,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${place.distance.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${place.duration.toStringAsFixed(0)} min',
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
                            elevation: 0,
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'coffee shop':
        return Icons.local_cafe;
      case 'grocery':
        return Icons.local_grocery_store;
      case 'gym':
        return Icons.fitness_center;
      case 'restaurant':
        return Icons.restaurant;
      case 'pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.place;
    }
  }

  Future<void> _onEmbeddedRouteEvent(e) async {
    _distanceRemaining = await MapBoxNavigation.instance.getDistanceRemaining();
    _durationRemaining = await MapBoxNavigation.instance.getDurationRemaining();

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
  final double distance;
  final double duration;
  final double rating;
  final String category;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    required this.distance,
    required this.duration,
    required this.rating,
    required this.category,
  });
}

// Place Details Bottom Sheet
class PlaceDetailsSheet extends StatelessWidget {
  final Place place;
  final VoidCallback onAdd;

  const PlaceDetailsSheet({
    super.key,
    required this.place,
    required this.onAdd,
  });

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
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Hero image placeholder
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey[200],
            child: Icon(
              _getCategoryIcon(place.category),
              size: 80,
              color: Colors.grey[400],
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
                  place.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 4),
                    Text(
                      place.rating.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.category, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(place.category),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        place.address,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${place.distance.toStringAsFixed(1)} km away'),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('~${place.duration.toStringAsFixed(0)} min drive'),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onAdd();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.add_location),
                        label: const Text('Add to Route'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'coffee shop':
        return Icons.local_cafe;
      case 'grocery':
        return Icons.local_grocery_store;
      case 'gym':
        return Icons.fitness_center;
      case 'restaurant':
        return Icons.restaurant;
      case 'pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.place;
    }
  }
}
