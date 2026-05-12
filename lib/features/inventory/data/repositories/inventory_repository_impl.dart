import '../../domain/repositories/inventory_repository.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import '../datasources/inventory_firebase_datasource.dart';

/// Implementation of InventoryRepository using Firestore.
class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryFirebaseDataSource _dataSource;

  InventoryRepositoryImpl({required InventoryFirebaseDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<List<InventoryItemEntity>> getItems(InventoryItemType type) async {
    return await _dataSource.getItems(type);
  }

  @override
  Future<List<InventoryItemEntity>> searchItems(
      InventoryItemType type, String query) async {
    return await _dataSource.searchItems(type, query);
  }

  @override
  Future<void> saveItem(InventoryItemEntity item) async {
    return await _dataSource.saveItem(item);
  }

  @override
  Future<void> updateItem(InventoryItemEntity item) async {
    return await _dataSource.updateItem(item);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    return await _dataSource.deleteItem(itemId);
  }

  @override
  Future<void> updateStock(String itemId, int newStock) async {
    return await _dataSource.updateStock(itemId, newStock);
  }
}