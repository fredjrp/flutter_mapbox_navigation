import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class CartListPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialCart;

  const CartListPage({Key? key, required this.initialCart}) : super(key: key);

  @override
  State<CartListPage> createState() => _CartListPageState();
}

class _CartListPageState extends State<CartListPage> with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _cart;
  bool _isOptimizing = false;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    // Copy the list to avoid mutating the original until explicitly passed back
    _cart = List.from(widget.initialCart);
    _sortCart();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Optimization simulation finished, return to app.dart and trigger checkout
        Navigator.pop(context, {'action': 'checkout', 'cart': _cart});
      }
    });
  }

  void _sortCart() {
    // Sort descending by priority (High: 2, Med: 1, Low: 0)
    _cart.sort((a, b) => (b['priority'] as int).compareTo(a['priority'] as int));
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _onOptimizeAndCheckout() {
    setState(() {
      _isOptimizing = true;
    });
    _progressController.forward();
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 2:
        return "High Priority";
      case 1:
        return "Medium Priority";
      case 0:
      default:
        return "Final Destination";
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 2:
        return Colors.orangeAccent;
      case 1:
        return Colors.blueAccent;
      case 0:
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isOptimizing) return false;
        Navigator.pop(context, {'action': 'update', 'cart': _cart});
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              if (!_isOptimizing) {
                Navigator.pop(context, {'action': 'update', 'cart': _cart});
              }
            },
          ),
          title: const Text(
            "Route Itinerary",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _cart.isEmpty
                      ? const Center(
                          child: Text(
                            "Your itinerary is empty.",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _cart.length,
                          itemBuilder: (context, index) {
                            final item = _cart[index];
                            final WayPoint wp = item['waypoint'];
                            final int priority = item['priority'];
                            final bool isLast = index == _cart.length - 1;

                            return Dismissible(
                              key: Key(wp.name ?? index.toString()),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) {
                                setState(() {
                                  _cart.removeAt(index);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("${wp.name} removed from itinerary")),
                                );
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Timeline styling
                                    SizedBox(
                                      width: 40,
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _getPriorityColor(priority),
                                              border: Border.all(color: Colors.white, width: 3),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 4,
                                                )
                                              ],
                                            ),
                                          ),
                                          if (!isLast)
                                            Expanded(
                                              child: Container(
                                                width: 2,
                                                color: Colors.grey[300],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Card Content
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 20),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.02),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _getPriorityLabel(priority),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getPriorityColor(priority),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                wp.name ?? "Unknown Location",
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Bottom Button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_cart.isEmpty || _isOptimizing) ? null : _onOptimizeAndCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Optimize & Checkout",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Loading Overlay
            if (_isOptimizing)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.9),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.route_outlined,
                          size: 64,
                          color: Colors.black,
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Optimizing Itinerary...",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 60),
                          child: AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: _progressAnimation.value,
                                      minHeight: 12,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "${(_progressAnimation.value * 100).toInt()}%",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
