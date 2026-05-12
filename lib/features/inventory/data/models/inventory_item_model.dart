import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';

/// Data model for InventoryItem with JSON serialization.
/// This model extends the domain entity to add persistence capabilities.
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

  /// Creates a model from JSON data.
  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    // Handle type conversion for enum
    InventoryItemType type;
    if (json['type'] == 'product') {
      type = InventoryItemType.product;
    } else if (json['type'] == 'material') {
      type = InventoryItemType.material;
    } else {
      throw FormatException('Invalid InventoryItemType: ${json['type']}');
    }

    return InventoryItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] as int,
      minStock: json['minStock'] as int,
      unit: json['unit'] as String,
      supplier: json['supplier'] as String?,
      code: json['code'] as String?,
    );
  }

  /// Converts the model to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.toString().split('.').last, // Convert enum to string
        'price': price,
        'stock': stock,
        'minStock': minStock,
        'unit': unit,
        'supplier': supplier,
        'code': code,
      };

  /// Creates a model from a domain entity.
  factory InventoryItemModel.fromEntity(InventoryItemEntity entity) => InventoryItemModel(
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

  /// Converts this model to a domain entity.
  InventoryItemEntity toEntity() => InventoryItemEntity(
        id: id,
        name: name,
        type: type,
        price: price,
        stock: stock,
        minStock: minStock,
        unit: unit,
        supplier: supplier,
        code: code,
      );
}