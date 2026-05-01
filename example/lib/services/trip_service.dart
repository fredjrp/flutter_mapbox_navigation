import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/cart_entry.dart';

class TripService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<TripRecord?> startTrip({
    required String userId,
    required List<CartEntry> cartEntries,
  }) async {
    try {
      final tripId = _uuid.v4();
      final record = TripRecord(
        id: tripId,
        userId: userId,
        storeIds: cartEntries.map((e) => e.store.id).toList(),
        storeNames: cartEntries.map((e) => e.store.name).toList(),
        itemCount: cartEntries.fold(0, (s, e) => s + e.items.length),
        startedAt: DateTime.now(),
        status: 'active',
        totalDistanceKm: 0,
      );
      await _db.collection('trips').doc(tripId).set(record.toFirestore());
      return record;
    } catch (_) {
      return null;
    }
  }

  Future<void> completeTrip(String tripId, double distanceKm) async {
    await _db.collection('trips').doc(tripId).update({
      'status': 'completed',
      'completedAt': Timestamp.now(),
      'totalDistanceKm': distanceKm,
    });
    // Increment user counters
  }

  Future<void> cancelTrip(String tripId) async {
    await _db.collection('trips').doc(tripId).update({'status': 'cancelled'});
  }

  Stream<List<TripRecord>> userTripsStream(String userId) {
    return _db
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TripRecord.fromFirestore(d)).toList());
  }

  Future<List<TripRecord>> getUserTrips(String userId) async {
    final snap = await _db
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .get();
    return snap.docs.map((d) => TripRecord.fromFirestore(d)).toList();
  }
}
