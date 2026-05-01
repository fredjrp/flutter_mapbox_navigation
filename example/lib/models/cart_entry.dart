import 'store.dart';

class CartEntry {
  final Store store;
  final List<StoreItem> items;

  CartEntry({required this.store, required this.items});

  CartEntry copyWith({Store? store, List<StoreItem>? items}) =>
      CartEntry(store: store ?? this.store, items: items ?? this.items);
}
