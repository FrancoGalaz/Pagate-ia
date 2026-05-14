import 'package:flutter/foundation.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import '../../domain/repositories/inventory_repository.dart';

class InventoryProvider extends ChangeNotifier {
  final InventoryRepository _repository;

  List<InventoryItemEntity> _items = [];
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

    try {
      _items = await _repository.searchItems(_activeTab, _searchQuery);
    } catch (_) {
      _items = [];
    }

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
      id: '', // Firestore will generate the ID
      name: name,
      type: type,
      price: price,
      stock: stock,
      minStock: minStock,
      unit: unit,
      supplier: 'Manual',
      code: null,
    );
    await _repository.saveItem(item);
    await _load();
  }

  Future<void> updateStock({
    required String itemId,
    required int newStock,
  }) async {
    await _repository.updateStock(itemId, newStock);
    await _load();
  }

  Future<void> deleteItem(String itemId) async {
    await _repository.deleteItem(itemId);
    await _load();
  }
}