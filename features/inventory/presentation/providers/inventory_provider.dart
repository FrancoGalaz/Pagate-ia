import 'package:flutter/foundation.dart';
import '../../data/repositories/mock_inventory_repository.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';

class InventoryProvider extends ChangeNotifier {
  final MockInventoryRepository _repository;

  List<InventoryItemEntity> _items = [];
  InventoryItemType _activeTab = InventoryItemType.product;
  String _searchQuery = '';
  bool _isLoading = false;

  InventoryProvider({required final MockInventoryRepository repository})
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
    _items = await _repository.searchItems(_activeTab, _searchQuery);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setActiveTab(final InventoryItemType type) async {
    _activeTab = type;
    _searchQuery = '';
    await _load();
  }

  Future<void> search(final String query) async {
    _searchQuery = query;
    await _load();
  }
}
