import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/store_service.dart';
import '../store/stores_list_screen.dart';
import '../cart/cart_screen.dart';
import '../store/store_map_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreService>().fetchNearbyStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final pages = [
      const StoresListScreen(),
      const StoreMapScreen(),
      const CartScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Stores',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: badges.Badge(
              showBadge: cart.totalItems > 0,
              badgeContent: Text('${cart.totalItems}',
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: badges.Badge(
              showBadge: cart.totalItems > 0,
              badgeContent: Text('${cart.totalItems}',
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
