import '../entities/inventory_item_entity.dart';
import '../entities/inventory_item_type.dart';

abstract class InventoryRepository {
  Future<List<InventoryItemEntity>> getItems(InventoryItemType type);
  Future<List<InventoryItemEntity>> searchItems(InventoryItemType type, String query);
  Future<void> saveItem(InventoryItemEntity item);
  Future<void> updateItem(InventoryItemEntity item);
  Future<void> deleteItem(String itemId);
  Future<void> updateStock(String itemId, int newStock);
}