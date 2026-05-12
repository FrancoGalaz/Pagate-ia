import 'package:flutter/foundation.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import '../../domain/repositories/inventory_repository.dart';

class InventoryProvider extends ChangeNotifier {
  final InventoryRepository _repository;

  List<InventoryItemEntity> _items = [];
  final List<InventoryItemEntity> _customItems = [];
  final Map<String, int> _stockOverrides = {};
  final Set<String> _deletedIds = {};
  InventoryItemType _activeTab = InventoryItemType.product;
  String _searchQuery = '';
  bool _isLoading = false;

  InventoryProvider({required InventoryRepository repository})
      : _repository = repository {
    _load();
  }

  List<InventoryItemEntity> get items => _items;
  InventoryItemType get activeTab => _activeTab;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();

    final repoItems = await _repository.searchItems(_activeTab, _searchQuery);
    final customItems = _customItems
        .where((item) => item.type == _activeTab)
        .where((item) => _matchesQuery(item, _searchQuery))
        .toList();

    _items = [
      ...customItems,
      ...repoItems,
    ]
        .where((item) => !_deletedIds.contains(item.id))
        .map(
          (item) => item.copyWith(
            stock: _stockOverrides[item.id] ?? item.stock,
          ),
        )
        .toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setActiveTab(InventoryItemType type) async {
    _activeTab = type;
    _searchQuery = '';
    await _load();
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    await _load();
  }

  Future<void> addItem({
    required String name,
    required InventoryItemType type,
    required double price,
    required int stock,
    required int minStock,
    required String unit,
  }) async {
    final item = InventoryItemEntity(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: type,
      price: price,
      stock: stock,
      minStock: minStock,
      unit: unit,
      supplier: 'Manual',
      code: null,
    );
    _customItems.insert(0, item);
    await _load();
  }

  Future<void> updateStock({
    required String itemId,
    required int newStock,
  }) async {
    _stockOverrides[itemId] = newStock;
    await _load();
  }

  Future<void> deleteItem(String itemId) async {
    _deletedIds.add(itemId);
    _stockOverrides.remove(itemId);
    _customItems.removeWhere((item) => item.id == itemId);
    await _load();
  }

  bool _matchesQuery(InventoryItemEntity item, String query) {
    if (query.isEmpty) return true;
    final lower = query.toLowerCase();
    return item.name.toLowerCase().contains(lower) ||
        (item.code?.toLowerCase().contains(lower) ?? false);
  }
}