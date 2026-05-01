import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/store.dart';

class StoreService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Store> _stores = [];
  List<Store> get stores => _stores;

  List<Store> _nearbyStores = [];
  List<Store> get nearbyStores => _nearbyStores;

  Position? _userPosition;
  Position? get userPosition => _userPosition;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  // ─── Location ────────────────────────────────────────────────────────────────

  Future<bool> fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'Location services are disabled.';
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _error = 'Location permission denied.';
          notifyListeners();
          return false;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _error = 'Location permission permanently denied.';
        notifyListeners();
        return false;
      }

      _userPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not get location.';
      notifyListeners();
      return false;
    }
  }

  // ─── Fetch Stores ─────────────────────────────────────────────────────────────

  Future<void> fetchAllStores() async {
    _loading = true;
    notifyListeners();
    try {
      final snapshot = await _db
          .collection('stores')
          .orderBy('name')
          .get();
      _stores = snapshot.docs.map((d) => Store.fromFirestore(d)).toList();
      _sortByDistance();
    } catch (e) {
      _error = 'Failed to load stores.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetch stores within [radiusKm] kilometres of the user
  Future<void> fetchNearbyStores({double radiusKm = 10}) async {
    _loading = true;
    notifyListeners();
    try {
      if (_userPosition == null) await fetchUserLocation();
      final snapshot = await _db.collection('stores').get();
      final all = snapshot.docs.map((d) => Store.fromFirestore(d)).toList();

      if (_userPosition != null) {
        _nearbyStores = all.where((s) {
          return s.distanceFrom(_userPosition!.latitude, _userPosition!.longitude) <= radiusKm;
        }).toList();
        _nearbyStores.sort((a, b) => a
            .distanceFrom(_userPosition!.latitude, _userPosition!.longitude)
            .compareTo(b.distanceFrom(
                _userPosition!.latitude, _userPosition!.longitude)));
      } else {
        _nearbyStores = all;
      }
      _stores = all;
    } catch (e) {
      _error = 'Failed to load nearby stores.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Stream<List<Store>> storesStream() {
    return _db.collection('stores').snapshots().map(
        (snap) => snap.docs.map((d) => Store.fromFirestore(d)).toList());
  }

  Future<Store?> fetchStore(String storeId) async {
    try {
      final doc = await _db.collection('stores').doc(storeId).get();
      if (doc.exists) return Store.fromFirestore(doc);
    } catch (_) {}
    return null;
  }

  // ─── Sorting ─────────────────────────────────────────────────────────────────

  void _sortByDistance() {
    if (_userPosition == null) return;
    _stores.sort((a, b) => a
        .distanceFrom(_userPosition!.latitude, _userPosition!.longitude)
        .compareTo(
            b.distanceFrom(_userPosition!.latitude, _userPosition!.longitude)));
  }

  double? distanceToStore(Store store) {
    if (_userPosition == null) return null;
    return store.distanceFrom(_userPosition!.latitude, _userPosition!.longitude);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
