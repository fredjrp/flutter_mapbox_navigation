import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/store_service.dart';
import '../../models/store.dart';
import 'store_detail_screen.dart';

class StoresListScreen extends StatefulWidget {
  const StoresListScreen({super.key});

  @override
  State<StoresListScreen> createState() => _StoresListScreenState();
}

class _StoresListScreenState extends State<StoresListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<StoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DropShip Navigator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => service.fetchNearbyStores(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Nearby', icon: Icon(Icons.near_me)),
            Tab(text: 'All Stores', icon: Icon(Icons.store)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search stores or items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StoreGrid(
                  stores: _filter(service.nearbyStores),
                  loading: service.loading,
                  emptyMsg: 'No nearby stores found.\nTry expanding your radius.',
                  service: service,
                ),
                _StoreGrid(
                  stores: _filter(service.stores),
                  loading: service.loading,
                  emptyMsg: 'No stores found.',
                  service: service,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Store> _filter(List<Store> stores) {
    if (_search.isEmpty) return stores;
    return stores.where((s) {
      return s.name.toLowerCase().contains(_search) ||
          s.address.toLowerCase().contains(_search) ||
          s.items.any((i) => i.name.toLowerCase().contains(_search));
    }).toList();
  }
}

class _StoreGrid extends StatelessWidget {
  final List<Store> stores;
  final bool loading;
  final String emptyMsg;
  final StoreService service;

  const _StoreGrid({
    required this.stores,
    required this.loading,
    required this.emptyMsg,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stores.isEmpty) {
      return Center(
          child: Text(emptyMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stores.length,
      itemBuilder: (context, i) => _StoreCard(
          store: stores[i], distance: service.distanceToStore(stores[i])),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  final double? distance;

  const _StoreCard({required this.store, this.distance});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => StoreDetailScreen(store: store))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store image
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  store.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: store.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.store, size: 48,
                                  color: Colors.grey)),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.store,
                              size: 48, color: Colors.grey)),
                  // Open/Closed badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: store.isOpen ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        store.isOpen ? 'Open' : 'Closed',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(store.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 11)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.access_time,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('${store.openingHours} - ${store.closingHours}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                    if (distance != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.near_me,
                            size: 12, color: Colors.blue.shade400),
                        const SizedBox(width: 4),
                        Text(
                          '${distance!.toStringAsFixed(1)} km away',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade400),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
