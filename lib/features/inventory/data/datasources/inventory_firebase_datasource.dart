import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item_model.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';

/// Firebase data source for inventory items.
/// Handles CRUD operations with Firestore, filtering by userId.
class InventoryFirebaseDataSource {
  final FirebaseFirestore _firestore;
  final String _userId;

  InventoryFirebaseDataSource({
    required FirebaseFirestore firestore,
    required String userId,
  })  : _firestore = firestore,
        _userId = userId;

  /// Collection reference for inventory items.
  CollectionReference get _itemsCollection =>
      _firestore.collection('inventory_items');

  /// Fetches all items of a specific type for the current user.
  Future<List<InventoryItemEntity>> getItems(InventoryItemType type) async {
    try {
      final querySnapshot = await _itemsCollection
          .where('userId', isEqualTo: _userId)
          .where('type', isEqualTo: type.toString().split('.').last)
          .get();

      return querySnapshot.docs
          .map((doc) => InventoryItemModel.fromJson(
                doc.data() as Map<String, dynamic>,
              ).toEntity())
          .toList();
    } catch (e) {
      // In case of offline mode or errors, return empty list gracefully.
      return [];
    }
  }

  /// Searches items by type and query for the current user.
  Future<List<InventoryItemEntity>> searchItems(
      InventoryItemType type, String query) async {
    try {
      final baseQuery = _itemsCollection
          .where('userId', isEqualTo: _userId)
          .where('type', isEqualTo: type.toString().split('.').last);

      final querySnapshot = await baseQuery.get();

      final items = querySnapshot.docs
          .map((doc) => InventoryItemModel.fromJson(
                doc.data() as Map<String, dynamic>,
              ))
          .where((item) => _matchesQuery(item, query))
          .map((item) => item.toEntity())
          .toList();

      return items;
    } catch (e) {
      // In case of offline mode or errors, return empty list gracefully.
      return [];
    }
  }

  /// Saves an item to Firestore.
  Future<void> saveItem(InventoryItemEntity item) async {
    final model = InventoryItemModel.fromEntity(item);

    await _itemsCollection.doc(item.id).set({
      ...model.toJson(),
      'userId': _userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates an item in Firestore.
  Future<void> updateItem(InventoryItemEntity item) async {
    final model = InventoryItemModel.fromEntity(item);

    await _itemsCollection.doc(item.id).update({
      ...model.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes an item from Firestore.
  Future<void> deleteItem(String itemId) async {
    await _itemsCollection.doc(itemId).delete();
  }

  /// Updates the stock of an item.
  Future<void> updateStock(String itemId, int newStock) async {
    await _itemsCollection.doc(itemId).update({
      'stock': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Helper method to check if an item matches a search query.
  bool _matchesQuery(InventoryItemModel item, String query) {
    if (query.isEmpty) return true;
    final lower = query.toLowerCase();
    return item.name.toLowerCase().contains(lower) ||
        (item.code?.toLowerCase().contains(lower) ?? false);
  }
}