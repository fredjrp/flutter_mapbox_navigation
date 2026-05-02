import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class LocationProductPage extends StatefulWidget {
  final WayPoint location;
  final String? address;
  final String? imageUrl;

  const LocationProductPage({
    Key? key,
    required this.location,
    this.address,
    this.imageUrl,
  }) : super(key: key);

  @override
  State<LocationProductPage> createState() => _LocationProductPageState();
}

class _LocationProductPageState extends State<LocationProductPage> {
  int _quantity = 1;
  int _selectedPriorityIndex = 1; // 0 = Low, 1 = Medium, 2 = High
  bool _isAddedToCart = false;

  final List<Color> _priorityColors = [
    Colors.green.shade400, // Low priority
    Colors.blue.shade400,  // Medium priority
    Colors.red.shade400,   // High priority
  ];

  final List<String> _priorityLabels = ["Low", "Medium", "High"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Placeholder Image Carousel
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: PageView.builder(
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Container(
                        color: Colors.grey[100],
                        child: widget.imageUrl != null && index == 0
                            ? Image.network(
                                widget.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
                              )
                            : Center(
                                child: Icon(Icons.landscape, color: Colors.grey[300], size: 80),
                              ),
                      );
                    },
                  ),
                ),
                
                // 2. Details Section (Whitespace Premium Feel)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.location.name ?? "Pinned Location",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.address ?? "Coordinates: ${widget.location.latitude}, ${widget.location.longitude}",
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // 3. Variations (Route Priority)
                      const Text(
                        "Route Priority",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: List.generate(_priorityColors.length, (index) {
                          final isSelected = _selectedPriorityIndex == index;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedPriorityIndex = index),
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? _priorityColors[index] : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: _priorityColors[index],
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _priorityLabels[_selectedPriorityIndex],
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // 4. Quantity Selector
                      const Text(
                        "Quantity / Packages",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              color: Colors.black87,
                              onPressed: () {
                                if (_quantity > 1) setState(() => _quantity--);
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                "$_quantity",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              color: Colors.black87,
                              onPressed: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 5. Bottom Right Split Button
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Add to Cart Button
                      Material(
                        color: _isAddedToCart ? Colors.grey[200] : Colors.black,
                        child: InkWell(
                          onTap: _isAddedToCart ? null : () {
                            setState(() {
                              _isAddedToCart = true;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Center(
                              child: Text(
                                _isAddedToCart ? "Added" : "Add to Route",
                                style: TextStyle(
                                  color: _isAddedToCart ? Colors.black54 : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Proceed Button (Disabled until added)
                      Material(
                        color: _isAddedToCart ? Colors.blue : Colors.grey[300],
                        child: InkWell(
                          onTap: _isAddedToCart ? () {
                            // Return the customized waypoint back to main screen
                            Navigator.of(context).pop(widget.location);
                          } : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Center(
                              child: Text(
                                "Proceed",
                                style: TextStyle(
                                  color: _isAddedToCart ? Colors.white : Colors.black38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
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
        ],
      ),
    );
  }
}
