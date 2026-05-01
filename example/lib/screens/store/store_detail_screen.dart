import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/store.dart';
import '../../services/cart_service.dart';

class StoreDetailScreen extends StatelessWidget {
  final Store store;
  const StoreDetailScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image app bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(store.name,
                  style: const TextStyle(
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
              background: store.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: store.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.store, size: 80)),
                    )
                  : Container(
                      color: Colors.blue.shade100,
                      child: const Icon(Icons.store, size: 80)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store info row
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: store.isOpen ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        store.isOpen ? '● Open' : '● Closed',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.access_time,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                                '${store.openingHours} – ${store.closingHours}',
                                style: const TextStyle(color: Colors.grey)),
                          ]),
                          Row(children: [
                            const Icon(Icons.location_on,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(store.address,
                                  style:
                                      const TextStyle(color: Colors.grey),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  // Items header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Available Items (${store.items.length})',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      if (cart.hasStore(store.id))
                        TextButton.icon(
                          icon: const Icon(Icons.shopping_cart),
                          label: Text(
                              '${cart.itemsForStore(store.id).length} in cart'),
                          onPressed: () => Navigator.pop(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Items list
          store.items.isEmpty
              ? const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No items available at this store.',
                        style: TextStyle(color: Colors.grey)),
                  )),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = store.items[i];
                      final inCart = cart.isItemInCart(store.id, item.id);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: item.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: item.imageUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                        width: 56,
                                        height: 56,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.inventory_2)),
                                  ),
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.inventory_2,
                                      color: Colors.blue)),
                          title: Text(item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12)),
                              Text('\$${item.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Color(0xFF1A73E8),
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          trailing: item.isAvailable
                              ? IconButton(
                                  icon: Icon(
                                    inCart
                                        ? Icons.check_circle
                                        : Icons.add_circle_outline,
                                    color: inCart
                                        ? Colors.green
                                        : const Color(0xFF1A73E8),
                                    size: 32,
                                  ),
                                  onPressed: () {
                                    if (inCart) {
                                      cart.removeItem(store.id, item.id);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  '${item.name} removed from cart'),
                                              duration: const Duration(
                                                  seconds: 1)));
                                    } else {
                                      cart.addItem(store, item);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  '${item.name} added to cart'),
                                              duration: const Duration(
                                                  seconds: 1)));
                                    }
                                  },
                                )
                              : const Chip(
                                  label: Text('Unavailable',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white)),
                                  backgroundColor: Colors.grey,
                                  padding: EdgeInsets.zero,
                                ),
                          isThreeLine: true,
                        ),
                      );
                    },
                    childCount: store.items.length,
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
