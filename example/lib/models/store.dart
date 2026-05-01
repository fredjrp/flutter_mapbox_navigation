import 'package:cloud_firestore/cloud_firestore.dart';

class StoreItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;

  StoreItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
  });

  factory StoreItem.fromMap(Map<String, dynamic> map, String id) {
    return StoreItem(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
      isAvailable: map['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
        'isAvailable': isAvailable,
      };
}

class Store {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String openingHours;
  final String closingHours;
  final bool isOpen;
  final List<StoreItem> items;
  final DateTime createdAt;

  Store({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    required this.openingHours,
    required this.closingHours,
    required this.isOpen,
    required this.items,
    required this.createdAt,
  });

  factory Store.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsData = (data['items'] as List<dynamic>?) ?? [];
    return Store(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'],
      openingHours: data['openingHours'] ?? '08:00',
      closingHours: data['closingHours'] ?? '18:00',
      isOpen: data['isOpen'] ?? true,
      items: itemsData
          .asMap()
          .entries
          .map((e) => StoreItem.fromMap(e.value as Map<String, dynamic>, e.key.toString()))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'imageUrl': imageUrl,
        'openingHours': openingHours,
        'closingHours': closingHours,
        'isOpen': isOpen,
        'items': items.map((i) => i.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  /// Distance in km from a given lat/lng (simple Haversine approx)
  double distanceFrom(double lat, double lng) {
    const earthR = 6371.0;
    final dLat = _toRad(latitude - lat);
    final dLng = _toRad(longitude - lng);
    final a = _sin2(dLat / 2) +
        _sin2(dLng / 2) * _cos(_toRad(lat)) * _cos(_toRad(latitude));
    return earthR * 2 * _atan2(_sqrt(a), _sqrt(1 - a));
  }

  double _toRad(double deg) => deg * 3.14159265358979 / 180;
  double _sin2(double x) => _sin(x) * _sin(x);
  double _sin(double x) => x - x * x * x / 6;
  double _cos(double x) => 1 - x * x / 2;
  double _sqrt(double x) => x <= 0 ? 0 : x * (1 - (x - 1) / 2);
  double _atan2(double y, double x) => x == 0 ? 1.5708 : y / x;
}
