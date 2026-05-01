import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final int totalTrips;
  final int totalItemsCollected;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.totalTrips = 0,
    this.totalItemsCollected = 0,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalTrips: data['totalTrips'] ?? 0,
      totalItemsCollected: data['totalItemsCollected'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'totalTrips': totalTrips,
        'totalItemsCollected': totalItemsCollected,
      };
}

class TripRecord {
  final String id;
  final String userId;
  final List<String> storeIds;
  final List<String> storeNames;
  final int itemCount;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String status; // 'active', 'completed', 'cancelled'
  final double totalDistanceKm;

  TripRecord({
    required this.id,
    required this.userId,
    required this.storeIds,
    required this.storeNames,
    required this.itemCount,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.totalDistanceKm,
  });

  factory TripRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      storeIds: List<String>.from(data['storeIds'] ?? []),
      storeNames: List<String>.from(data['storeNames'] ?? []),
      itemCount: data['itemCount'] ?? 0,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      status: data['status'] ?? 'active',
      totalDistanceKm: (data['totalDistanceKm'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'storeIds': storeIds,
        'storeNames': storeNames,
        'itemCount': itemCount,
        'startedAt': Timestamp.fromDate(startedAt),
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'status': status,
        'totalDistanceKm': totalDistanceKm,
      };
}
