// Repositorio de inventario falso, compartido por los tests de la feature.
//
// Sin Firebase, como manda AGENTS.md: el stream lo alimenta el test con
// [emitir] y las escrituras se quedan en listas que el test inspecciona. Es
// lo que permite comprobar QUÉ se guarda, que es justo lo que no se podía
// comprobar mientras `supplier` y `code` no salían de ningún formulario.

import 'dart:async';

import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/inventory/domain/repositories/inventory_repository.dart';

class FakeInventoryRepository implements InventoryRepository {
  /// `broadcast` porque el provider vuelve a suscribirse en cada
  /// `setActiveTab` y en cada `retry`.
  final StreamController<List<InventoryItemEntity>> _items =
      StreamController<List<InventoryItemEntity>>.broadcast();

  final List<InventoryItemEntity> agregados = [];
  final List<InventoryItemEntity> actualizados = [];
  final List<String> borrados = [];
  final List<int> stocksEscritos = [];

  /// Si no es nulo, `addItem` y `updateItem` lo lanzan en vez de guardar. Es
  /// lo que permite probar el camino de error.
  Object? errorAlGuardar;

  /// Hace que el stream reemita, como haría Firestore tras una escritura.
  void emitir(final List<InventoryItemEntity> items) => _items.add(items);

  Future<void> cerrar() => _items.close();

  @override
  Stream<List<InventoryItemEntity>> watchItems(final InventoryItemType type) =>
      _items.stream;

  @override
  Future<void> addItem(final InventoryItemEntity item) async {
    final error = errorAlGuardar;
    if (error != null) throw error;
    agregados.add(item);
  }

  @override
  Future<void> updateItem(final InventoryItemEntity item) async {
    final error = errorAlGuardar;
    if (error != null) throw error;
    actualizados.add(item);
  }

  @override
  Future<void> deleteItem(final String itemId) async => borrados.add(itemId);

  @override
  Future<void> updateStock(final String itemId, final int newStock) async =>
      stocksEscritos.add(newStock);
}
