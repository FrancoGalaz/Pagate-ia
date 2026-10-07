import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_limits.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import '../models/inventory_item_model.dart';

/// Acceso a Firestore para el inventario bajo `users/{uid}/inventory`.
class InventoryFirebaseDataSource {
  final FirebaseFirestore _firestore;
  final String _userId;

  InventoryFirebaseDataSource({
    required FirebaseFirestore firestore,
    required String userId,
  })  : _firestore = firestore,
        _userId = userId;

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection('users').doc(_userId).collection('inventory');

  /// Items de un tipo ordenados por nombre.
  ///
  /// Se filtra por `type` en Firestore y se ordena en memoria para no
  /// depender de un índice compuesto `type + name`.
  ///
  /// El `.limit()` es OBLIGATORIO: sin él la regla `list` deniega la consulta
  /// completa y el inventario se ve vacío (ver [FirestoreLimits]).
  Stream<List<InventoryItemEntity>> watchItems(final InventoryItemType type) =>
      _items
          .where('type', isEqualTo: type.name)
          .limit(FirestoreLimits.maxList)
          .snapshots()
          .map((final snapshot) {
            final items = snapshot.docs
                .map(
                  (final doc) =>
                      InventoryItemModel.fromDoc(doc.id, doc.data()),
                )
                .toList();
            items.sort(
              (final a, final b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
            return items;
          });

  /// TODO el inventario, de los dos tipos, ordenado por nombre.
  ///
  /// Lo necesita el lector de boletas: una boleta de compra de materiales se
  /// puede leer estando en la pestaña de Productos, y emparejar solo contra
  /// la pestaña activa crearía una ficha duplicada del material que el
  /// usuario ya tiene. El emparejamiento mira los dos tipos.
  ///
  /// El `.limit()` sigue siendo obligatorio por la regla `list` (ver
  /// [FirestoreLimits]); aquí cuenta sobre la colección entera en vez de
  /// sobre un tipo, así que con más de 200 fichas habría que paginar. El
  /// sitio donde se decide eso es `firestore_limits.dart`.
  Stream<List<InventoryItemEntity>> watchAllItems() => _items
      .limit(FirestoreLimits.maxList)
      .snapshots()
      .map((final snapshot) {
        final items = snapshot.docs
            .map((final doc) => InventoryItemModel.fromDoc(doc.id, doc.data()))
            .toList();
        items.sort(
          (final a, final b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return items;
      });

  /// Crea un item con id generado por Firestore. El `id` de la entidad se
  /// ignora.
  Future<void> addItem(final InventoryItemEntity item) async {
    final model = InventoryItemModel.fromEntity(item);
    await _items.add({
      ...model.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem(final InventoryItemEntity item) async {
    final model = InventoryItemModel.fromEntity(item);
    await _items.doc(item.id).update({
      ...model.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(final String itemId) => _items.doc(itemId).delete();

  Future<void> updateStock(final String itemId, final int newStock) =>
      _items.doc(itemId).update({
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Escribe de golpe todo lo que el usuario confirmó de una boleta.
  ///
  /// UN `WriteBatch`, no un bucle de `addItem`. El lote es atómico: o entran
  /// las 15 fichas o no entra ninguna, así que no existe el estado de
  /// "media boleta guardada", que es el peor de los tres (el usuario no
  /// sabe qué mitad le falta y volver a leer la boleta duplicaría la otra).
  ///
  /// Tres detalles verificados, no supuestos:
  ///
  /// · El tope de Firestore es de 500 operaciones por lote y el nuestro es
  ///   de 40 fichas nuevas más 40 actualizaciones: holgado.
  /// · Cada escritura del lote se evalúa POR SEPARADO contra
  ///   `firestore.rules`, así que `validInventoryItem` sigue aplicando ficha
  ///   a ficha; el lote no es una puerta de atrás.
  /// · `FieldValue.serverTimestamp()` dentro de un lote resuelve a la hora
  ///   de confirmación, que es la misma `request.time` que exige
  ///   `validTimestampsOnCreate`. Es el patrón que ya usa [addItem].
  ///
  /// Los campos que se escriben son los que `validInventoryItem` ya
  /// aceptaba, `supplier` y `code` incluidos: el escáner no añade ni uno
  /// nuevo, así que las reglas no cambian.
  Future<void> applyScannedItems({
    required final List<InventoryItemEntity> nuevos,
    required final Map<String, int> stocksFinales,
    required final Map<String, double> preciosNuevos,
  }) async {
    if (nuevos.isEmpty && stocksFinales.isEmpty && preciosNuevos.isEmpty) {
      return;
    }

    final lote = _firestore.batch();

    for (final item in nuevos) {
      final model = InventoryItemModel.fromEntity(item);
      lote.set(_items.doc(), {
        ...model.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Las dos actualizaciones de una misma ficha (stock y precio) se
    // juntan en UNA operación. Dos `update` sobre el mismo documento en el
    // mismo lote es un error de Firestore, y además gastaría dos de las
    // 500 por nada.
    final ids = {...stocksFinales.keys, ...preciosNuevos.keys};
    for (final id in ids) {
      lote.update(_items.doc(id), {
        if (stocksFinales.containsKey(id)) 'stock': stocksFinales[id],
        if (preciosNuevos.containsKey(id)) 'price': preciosNuevos[id],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await lote.commit();
  }
}
