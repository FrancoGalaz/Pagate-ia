import '../entities/inventory_item_entity.dart';
import '../entities/inventory_item_type.dart';

/// Contrato de acceso al inventario. La lectura es un stream por tipo; la
/// búsqueda por texto se resuelve en memoria en la capa de presentación.
abstract class InventoryRepository {
  /// Items de un tipo ordenados por nombre.
  Stream<List<InventoryItemEntity>> watchItems(InventoryItemType type);

  /// Crea un item. El `id` de [item] se ignora.
  Future<void> addItem(InventoryItemEntity item);

  Future<void> updateItem(InventoryItemEntity item);

  Future<void> deleteItem(String itemId);

  Future<void> updateStock(String itemId, int newStock);
}
