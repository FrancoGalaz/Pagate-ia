import 'package:cloud_firestore/cloud_firestore.dart';
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
  Stream<List<InventoryItemEntity>> watchItems(final InventoryItemType type) =>
      _items.where('type', isEqualTo: type.name).snapshots().map(
        (final snapshot) {
          final items = snapshot.docs
              .map((final doc) => InventoryItemModel.fromDoc(doc.id, doc.data()))
              .toList();
          items.sort(
            (final a, final b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return items;
        },
      );

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
}
