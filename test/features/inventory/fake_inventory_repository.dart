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

  /// El mismo stream: en los tests no hay filtro por tipo en Firestore, así
  /// que lo que emite [emitir] es a la vez "la pestaña" y "todo".
  @override
  Stream<List<InventoryItemEntity>> watchAllItems() => _items.stream;

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

  /// Lo que el lote habría escrito, para que un test pueda comprobar QUÉ
  /// se guarda de una boleta: las fichas nuevas, los stocks sumados y los
  /// precios que el usuario aprobó sobrescribir.
  final List<InventoryItemEntity> loteNuevos = [];
  final List<Map<String, int>> loteStocks = [];
  final List<Map<String, double>> lotePrecios = [];

  /// Cuántas veces se llamó al lote. Es lo que prueba que 15 artículos son
  /// UNA operación y no quince.
  int lotes = 0;

  @override
  Future<void> applyScannedItems({
    required final List<InventoryItemEntity> nuevos,
    required final Map<String, int> stocksFinales,
    required final Map<String, double> preciosNuevos,
  }) async {
    final error = errorAlGuardar;
    if (error != null) throw error;
    lotes++;
    loteNuevos.addAll(nuevos);
    loteStocks.add(stocksFinales);
    lotePrecios.add(preciosNuevos);
  }
}
