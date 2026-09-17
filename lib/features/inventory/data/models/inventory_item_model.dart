import 'package:flutter/foundation.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';

/// Modelo de item de inventario con serialización manual hacia/desde
/// Firestore (`users/{uid}/inventory/{itemId}`).
///
/// El documento NO contiene `id` ni `userId`.
class InventoryItemModel extends InventoryItemEntity {
  const InventoryItemModel({
    required super.id,
    required super.name,
    required super.type,
    required super.price,
    required super.stock,
    required super.minStock,
    required super.unit,
    super.supplier,
    super.code,
  });

  /// Construye el modelo desde un documento. Nunca lanza por tipos
  /// inesperados: usa valores por defecto seguros y lo registra.
  factory InventoryItemModel.fromDoc(
    final String id,
    final Map<String, dynamic> data,
  ) {
    final rawType = data['type'];
    InventoryItemType type;
    if (rawType == 'product') {
      type = InventoryItemType.product;
    } else if (rawType == 'material') {
      type = InventoryItemType.material;
    } else {
      debugPrint(
        'InventoryItemModel[$id]: type inesperado "$rawType", '
        'se asume product',
      );
      type = InventoryItemType.product;
    }

    return InventoryItemModel(
      id: id,
      name: _string(data['name'], id, 'name') ?? '',
      type: type,
      price: _num(data['price'], id, 'price').toDouble(),
      stock: _num(data['stock'], id, 'stock').toInt(),
      minStock: _num(data['minStock'], id, 'minStock').toInt(),
      unit: _string(data['unit'], id, 'unit') ?? 'unidades',
      supplier: _string(data['supplier'], id, 'supplier'),
      code: _string(data['code'], id, 'code'),
    );
  }

  /// Campos que se escriben en Firestore. No incluye `id` ni
  /// `createdAt`/`updatedAt` (los agrega el datasource).
  Map<String, dynamic> toFirestore() => {
        'name': name,
        'type': type.name,
        'price': price,
        'stock': stock,
        'minStock': minStock,
        'unit': unit,
        'supplier': supplier,
        'code': code,
      };

  factory InventoryItemModel.fromEntity(final InventoryItemEntity entity) =>
      InventoryItemModel(
        id: entity.id,
        name: entity.name,
        type: entity.type,
        price: entity.price,
        stock: entity.stock,
        minStock: entity.minStock,
        unit: entity.unit,
        supplier: entity.supplier,
        code: entity.code,
      );

  static String? _string(
    final Object? value,
    final String id,
    final String field,
  ) {
    if (value == null) return null;
    if (value is String) return value;
    debugPrint('InventoryItemModel[$id]: $field no es String ($value)');
    return null;
  }

  static num _num(final Object? value, final String id, final String field) {
    if (value is num) return value;
    debugPrint('InventoryItemModel[$id]: $field no es num ($value)');
    return 0;
  }
}
