import 'package:equatable/equatable.dart';
import 'inventory_item_type.dart';

class InventoryItemEntity extends Equatable {
  final String id;
  final String name;
  final InventoryItemType type;
  final double price;
  final int stock;
  final int minStock;
  final String unit; // e.g. "unidades", "kg", "litros"
  final String? supplier;
  final String? code;

  const InventoryItemEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.stock,
    required this.minStock,
    required this.unit,
    this.supplier,
    this.code,
  });

  InventoryItemEntity copyWith({
    final String? id,
    final String? name,
    final InventoryItemType? type,
    final double? price,
    final int? stock,
    final int? minStock,
    final String? unit,
    final String? supplier,
    final String? code,
  }) =>
      InventoryItemEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        price: price ?? this.price,
        stock: stock ?? this.stock,
        minStock: minStock ?? this.minStock,
        unit: unit ?? this.unit,
        supplier: supplier ?? this.supplier,
        code: code ?? this.code,
      );

  StockStatus get stockStatus {
    if (stock == 0) return StockStatus.critical;
    if (stock <= minStock) return StockStatus.low;
    return StockStatus.ok;
  }

  @override
  List<Object?> get props =>
      [id, name, type, price, stock, minStock, unit, supplier, code];
}
