import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import '../../services/store_service.dart';
import '../../models/store.dart';
import 'store_detail_screen.dart';

class StoreMapScreen extends StatefulWidget {
  const StoreMapScreen({super.key});

  @override
  State<StoreMapScreen> createState() => _StoreMapScreenState();
}

class _StoreMapScreenState extends State<StoreMapScreen> {
  MapBoxNavigationViewController? _controller;
  Store? _selectedStore;
  late MapBoxOptions _options;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _options = MapBoxNavigation.instance.getDefaultOptions();
    _options.simulateRoute = false;
    _options.language = 'en';
    MapBoxNavigation.instance.registerRouteEventListener(_onRouteEvent);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeService = context.watch<StoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              await storeService.fetchNearbyStores();
            },
            tooltip: 'Refresh location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapbox Navigation View (used as map viewer)
          MapBoxNavigationView(
            options: _options,
            onRouteEvent: _onRouteEvent,
            onCreated: (MapBoxNavigationViewController controller) {
              _controller = controller;
              controller.initialize();
              setState(() => _mapReady = true);
            },
          ),
          // Store list overlay at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStoreBottomSheet(storeService),
          ),
          // Selected store card
          if (_selectedStore != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildSelectedStoreCard(_selectedStore!),
            ),
        ],
      ),
    );
  }

  Widget _buildStoreBottomSheet(StoreService service) {
    final stores = service.nearbyStores.isEmpty
        ? service.stores
        : service.nearbyStores;

    return Container(
      height: 160,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nearby Stores',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: stores.length,
              itemBuilder: (context, i) =>
                  _StoreChip(store: stores[i], onTap: () {
                setState(() => _selectedStore = stores[i]);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedStoreCard(Store store) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.store, color: Color(0xFF1A73E8), size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(store.address,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('${store.openingHours} – ${store.closingHours}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => _navigateTo(store),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6)),
                  child: const Text('Navigate', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              StoreDetailScreen(store: store))),
                  child: const Text('Details',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selectedStore = null),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateTo(Store store) async {
    final storeService = context.read<StoreService>();
    final pos = storeService.userPosition;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Getting your location...')));
      return;
    }

    final origin = WayPoint(
      name: 'My Location',
      latitude: pos.latitude,
      longitude: pos.longitude,
      isSilent: false,
    );
    final destination = WayPoint(
      name: store.name,
      latitude: store.latitude,
      longitude: store.longitude,
      isSilent: false,
    );

    await MapBoxNavigation.instance.startNavigation(
      wayPoints: [origin, destination],
      options: MapBoxOptions(
        mode: MapBoxNavigationMode.driving,
        simulateRoute: false,
        language: 'en',
        units: VoiceUnits.metric,
        voiceInstructionsEnabled: true,
        bannerInstructionsEnabled: true,
      ),
    );
  }

  Future<void> _onRouteEvent(e) async {
    // Handle map route events if needed
  }
}

class _StoreChip extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;

  const _StoreChip({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10, bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: store.isOpen ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: store.isOpen ? Colors.blue.shade200 : Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.circle,
                  size: 10,
                  color: store.isOpen ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Expanded(
                child: Text(store.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 4),
            Text('${store.items.length} items',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
