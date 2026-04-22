import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import '../../../../core/constants/app_mock_data.dart';

class MockInventoryRepository {
  final List<InventoryItemEntity> _items =
      List.from(AppMockData.inventoryItems);

  Future<List<InventoryItemEntity>> getItems(final InventoryItemType type) async =>
      _items.where((final item) => item.type == type).toList();

  Future<List<InventoryItemEntity>> searchItems(
      final InventoryItemType type, final String query) async {
    final all = await getItems(type);
    if (query.isEmpty) return all;
    final lower = query.toLowerCase();
    return all
        .where((final item) =>
            item.name.toLowerCase().contains(lower) ||
            (item.code?.toLowerCase().contains(lower) ?? false))
        .toList();
  }
}
