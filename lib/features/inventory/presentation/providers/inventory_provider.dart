import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/error_messages.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Estado del inventario alimentado por un stream de Firestore.
///
/// Se suscribe al stream del tipo activo en el constructor (y al cambiar de
/// pestaña) y cancela en [dispose]. La búsqueda por texto se filtra en
/// memoria. Los errores de lectura se exponen en [error] con [retry]; los de
/// escritura se propagan al llamador.
class InventoryProvider extends ChangeNotifier {
  final InventoryRepository _repository;

  StreamSubscription<List<InventoryItemEntity>>? _itemsSub;

  List<InventoryItemEntity> _allItems = const [];
  InventoryItemType _activeTab = InventoryItemType.product;
  String _searchQuery = '';
  bool _loaded = false;
  String? _error;
  bool _disposed = false;

  InventoryProvider({required InventoryRepository repository})
      : _repository = repository {
    _subscribe();
  }

  // ─── Estado ───────────────────────────────────────────────────────

  /// Items del tipo activo que coinciden con la búsqueda, ordenados por nombre.
  List<InventoryItemEntity> get items {
    if (_searchQuery.isEmpty) return _allItems;
    final lower = _searchQuery.toLowerCase();
    return _allItems
        .where(
          (final item) =>
              item.name.toLowerCase().contains(lower) ||
              (item.code?.toLowerCase().contains(lower) ?? false),
        )
        .toList();
  }

  /// Todos los items del tipo activo, sin filtrar por búsqueda.
  List<InventoryItemEntity> get allItems => _allItems;

  InventoryItemType get activeTab => _activeTab;
  String get searchQuery => _searchQuery;
  bool get isLoading => !_loaded && _error == null;
  String? get error => _error;

  // ─── Acciones de lectura ──────────────────────────────────────────

  void setActiveTab(final InventoryItemType type) {
    if (type == _activeTab) return;
    _activeTab = type;
    _searchQuery = '';
    _subscribe();
  }

  void search(final String query) {
    final trimmed = query.trim();
    if (trimmed == _searchQuery) return;
    _searchQuery = trimmed;
    notifyListeners();
  }

  /// Cancela y vuelve a abrir la suscripción.
  void retry() => _subscribe();

  // ─── Escrituras ───────────────────────────────────────────────────

  Future<void> addItem({
    required final String name,
    required final InventoryItemType type,
    required final double price,
    required final int stock,
    required final int minStock,
    required final String unit,
    final String? supplier,
    final String? code,
  }) async {
    final safeName = name.trim();
    if (safeName.isEmpty) throw ArgumentError('El nombre es obligatorio');
    if (!price.isFinite || price < 0) {
      throw ArgumentError('El precio no puede ser negativo');
    }
    if (stock < 0 || minStock < 0) {
      throw ArgumentError('El stock no puede ser negativo');
    }
    await _repository.addItem(
      InventoryItemEntity(
        id: '',
        name: safeName,
        type: type,
        price: price,
        stock: stock,
        minStock: minStock,
        unit: unit.trim().isEmpty ? 'unidades' : unit.trim(),
        supplier: supplier,
        code: code,
      ),
    );
  }

  Future<void> updateItem(final InventoryItemEntity item) =>
      _repository.updateItem(item);

  Future<void> updateStock({
    required final String itemId,
    required final int newStock,
  }) {
    if (newStock < 0) throw ArgumentError('El stock no puede ser negativo');
    return _repository.updateStock(itemId, newStock);
  }

  Future<void> deleteItem(final String itemId) =>
      _repository.deleteItem(itemId);

  // ─── Suscripción y ciclo de vida ──────────────────────────────────

  void _subscribe() {
    _itemsSub?.cancel();
    _error = null;
    _loaded = false;
    _allItems = const [];
    _itemsSub = _repository.watchItems(_activeTab).listen(
      (final items) {
        _allItems = items;
        _loaded = true;
        _notify();
      },
      onError: (final Object error, final StackTrace stackTrace) {
        debugPrint('InventoryProvider: error en stream: $error\n$stackTrace');
        _error = describeError(error);
        _notify();
      },
    );
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _itemsSub?.cancel();
    _itemsSub = null;
    super.dispose();
  }

  /// Traduce una excepción a un mensaje corto en español.
  ///
  /// [operation] es obligatorio en la práctica para una escritura o un
  /// borrado: sin él, un `permission-denied` al GUARDAR se contaba como
  /// "No tienes permiso para ver estos datos", que es falso y además
  /// desorienta (el usuario los está viendo). La lógica vive en
  /// `core/utils/error_messages.dart`, compartida con InventoryProvider.
  static String describeError(
    final Object error, {
    final String? fallback,
    final DataOperation operation = DataOperation.read,
  }) =>
      describeDataError(error, operation: operation, fallback: fallback);
}
