import 'package:flutter/material.dart';
import '../models/cart_entry.dart';
import '../models/store.dart';

class CartService extends ChangeNotifier {
  final List<CartEntry> _entries = [];

  List<CartEntry> get entries => List.unmodifiable(_entries);

  int get totalItems =>
      _entries.fold(0, (sum, e) => sum + e.items.length);

  int get storeCount => _entries.length;

  bool hasStore(String storeId) =>
      _entries.any((e) => e.store.id == storeId);

  List<StoreItem> itemsForStore(String storeId) =>
      _entries.firstWhere((e) => e.store.id == storeId,
              orElse: () => CartEntry(store: _entries.first.store, items: []))
          .items;

  void addItem(Store store, StoreItem item) {
    final idx = _entries.indexWhere((e) => e.store.id == store.id);
    if (idx >= 0) {
      // Store already in cart — add item if not duplicate
      final existing = _entries[idx];
      if (!existing.items.any((i) => i.id == item.id)) {
        _entries[idx] = existing.copyWith(items: [...existing.items, item]);
      }
    } else {
      _entries.add(CartEntry(store: store, items: [item]));
    }
    notifyListeners();
  }

  void removeItem(String storeId, String itemId) {
    final idx = _entries.indexWhere((e) => e.store.id == storeId);
    if (idx < 0) return;
    final updated = _entries[idx]
        .items
        .where((i) => i.id != itemId)
        .toList();
    if (updated.isEmpty) {
      _entries.removeAt(idx);
    } else {
      _entries[idx] = _entries[idx].copyWith(items: updated);
    }
    notifyListeners();
  }

  void removeStore(String storeId) {
    _entries.removeWhere((e) => e.store.id == storeId);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  bool isItemInCart(String storeId, String itemId) {
    final entry = _entries.firstWhere(
      (e) => e.store.id == storeId,
      orElse: () => CartEntry(
          store: Store(
              id: '',
              name: '',
              address: '',
              latitude: 0,
              longitude: 0,
              openingHours: '',
              closingHours: '',
              isOpen: false,
              items: [],
              createdAt: DateTime.now()),
          items: []),
    );
    return entry.items.any((i) => i.id == itemId);
  }
}
