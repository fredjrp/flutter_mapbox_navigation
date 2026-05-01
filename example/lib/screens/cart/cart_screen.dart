import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/cart_service.dart';
import '../../services/auth_service.dart';
import '../../services/store_service.dart';
import '../../services/trip_service.dart';
import '../../models/cart_entry.dart';
import '../navigation/navigation_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          if (cart.entries.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, cart),
              child: const Text('Clear', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: cart.entries.isEmpty
          ? const _EmptyCart()
          : Column(
              children: [
                // Summary bar
                Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFF1A73E8), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${cart.totalItems} items from ${cart.storeCount} store${cart.storeCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: Color(0xFF1A73E8),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                // Cart entries
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.entries.length,
                    itemBuilder: (context, i) =>
                        _CartStoreCard(entry: cart.entries[i]),
                  ),
                ),
                // Navigate button
                _NavigateButton(entries: cart.entries),
              ],
            ),
    );
  }

  void _confirmClear(BuildContext context, CartService cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text(
            'Remove all items from your cart?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                cart.clear();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Clear All')),
        ],
      ),
    );
  }
}

class _CartStoreCard extends StatelessWidget {
  final CartEntry entry;
  const _CartStoreCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.store, color: Color(0xFF1A73E8)),
        title: Text(entry.store.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${entry.items.length} item(s) · ${entry.store.address}',
            style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => cart.removeStore(entry.store.id),
              tooltip: 'Remove store',
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: entry.items.map((item) {
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            leading: const Icon(Icons.inventory_2_outlined,
                color: Colors.grey, size: 20),
            title: Text(item.name,
                style: const TextStyle(fontSize: 14)),
            subtitle: Text('\$${item.price.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Color(0xFF1A73E8), fontSize: 13)),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.red, size: 20),
              onPressed: () => cart.removeItem(entry.store.id, item.id),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavigateButton extends StatefulWidget {
  final List<CartEntry> entries;
  const _NavigateButton({required this.entries});

  @override
  State<_NavigateButton> createState() => _NavigateButtonState();
}

class _NavigateButtonState extends State<_NavigateButton> {
  bool _loading = false;

  Future<void> _startNavigation() async {
    setState(() => _loading = true);
    try {
      final authService = context.read<AuthService>();
      final storeService = context.read<StoreService>();
      final tripService = TripService();

      // Record the trip
      final userId = authService.firebaseUser?.uid;
      if (userId != null) {
        await tripService.startTrip(
            userId: userId, cartEntries: widget.entries);
      }

      final pos = storeService.userPosition;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NavigationScreen(
            cartEntries: widget.entries,
            userLat: pos?.latitude,
            userLng: pos?.longitude,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _startNavigation,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.navigation_rounded),
        label: Text(
          'Navigate to ${widget.entries.length} Store${widget.entries.length > 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: Colors.green,
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Your cart is empty',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Browse stores and add items\nto build your pickup route.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.storefront),
            label: const Text('Browse Stores'),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
