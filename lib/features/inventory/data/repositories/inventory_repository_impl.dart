import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_firebase_datasource.dart';

/// Implementación de [InventoryRepository] sobre Firestore.
class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryFirebaseDataSource _dataSource;

  InventoryRepositoryImpl({required InventoryFirebaseDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Stream<List<InventoryItemEntity>> watchItems(final InventoryItemType type) =>
      _dataSource.watchItems(type);

  @override
  Future<void> addItem(final InventoryItemEntity item) =>
      _dataSource.addItem(item);

  @override
  Future<void> updateItem(final InventoryItemEntity item) =>
      _dataSource.updateItem(item);

  @override
  Future<void> deleteItem(final String itemId) => _dataSource.deleteItem(itemId);

  @override
  Future<void> updateStock(final String itemId, final int newStock) =>
      _dataSource.updateStock(itemId, newStock);
}
