import '../entities/inventory_item_entity.dart';
import '../entities/inventory_item_type.dart';

/// Contrato de acceso al inventario. La lectura es un stream por tipo; la
/// búsqueda por texto se resuelve en memoria en la capa de presentación.
abstract class InventoryRepository {
  /// Items de un tipo ordenados por nombre.
  Stream<List<InventoryItemEntity>> watchItems(InventoryItemType type);

  /// TODO el inventario, de los dos tipos, ordenado por nombre.
  ///
  /// Lo consume el lector de boletas para emparejar lo leído con lo que el
  /// usuario ya tiene, que no puede depender de qué pestaña estaba abierta.
  Stream<List<InventoryItemEntity>> watchAllItems();

  /// Crea un item. El `id` de [item] se ignora.
  Future<void> addItem(InventoryItemEntity item);

  Future<void> updateItem(InventoryItemEntity item);

  Future<void> deleteItem(String itemId);

  Future<void> updateStock(String itemId, int newStock);

  /// Guarda varias fichas y suma stock a otras en UNA SOLA operación
  /// atómica. O entra todo o no entra nada.
  ///
  /// Existe porque el lector de boletas confirma hasta 40 artículos de
  /// golpe y [addItem] escribe de uno en uno: con 15 llamadas sueltas, si
  /// la séptima falla queda media boleta dentro y el usuario no sabe qué
  /// mitad le falta. Media boleta guardada es peor que ninguna.
  ///
  /// - [nuevos]: fichas que no existían. El `id` se ignora.
  /// - [stocksFinales]: `itemId` → stock YA SUMADO. El cálculo lo hace
  ///   quien llama, con el stock que tenía a la vista cuando el usuario
  ///   confirmó; así lo que se guarda es lo que la pantalla prometió.
  /// - [preciosNuevos]: `itemId` → precio, SOLO para las fichas donde el
  ///   usuario aprobó explícitamente sobrescribirlo.
  Future<void> applyScannedItems({
    required List<InventoryItemEntity> nuevos,
    required Map<String, int> stocksFinales,
    required Map<String, double> preciosNuevos,
  });
}
