import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/firestore_limits.dart';
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

  /// Segunda suscripción, a TODO el inventario (los dos tipos).
  ///
  /// POR QUÉ HAY DOS Y NO UNA. La lista de la pestaña se filtra por `type`
  /// en Firestore, así que `allItems` solo trae el tipo activo. El lector de
  /// boletas necesita los DOS para emparejar: una boleta de materiales se
  /// puede leer estando en la pestaña de Productos, y mirar solo la activa
  /// crearía una ficha duplicada del material que el usuario ya tiene.
  ///
  /// Se añadió como segunda suscripción en vez de derivar la pestaña de
  /// esta, que sería un oyente menos, porque eso cambiaría el
  /// comportamiento de una pantalla que ya está probada y en producción. El
  /// coste es un oyente más por sesión sobre una colección topada a 200
  /// documentos.
  StreamSubscription<List<InventoryItemEntity>>? _completoSub;

  List<InventoryItemEntity> _inventarioCompleto = const [];

  List<InventoryItemEntity> _allItems = const [];
  InventoryItemType _activeTab = InventoryItemType.product;
  String _searchQuery = '';
  bool _loaded = false;
  String? _error;
  bool _disposed = false;

  InventoryProvider({required InventoryRepository repository})
      : _repository = repository {
    _subscribe();
    _subscribeCompleto();
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

  /// TODO el inventario, productos y materiales, sin filtrar por nada.
  ///
  /// Lo usa el lector de boletas para emparejar. Puede llegar vacío durante
  /// el primer frame; el emparejamiento con una lista vacía simplemente
  /// propone fichas nuevas, que es el comportamiento correcto cuando no se
  /// sabe qué hay.
  List<InventoryItemEntity> get inventarioCompleto => _inventarioCompleto;

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
        supplier: _opcional(supplier),
        code: _opcional(code),
      ),
    );
  }

  /// Guarda los cambios de una ficha que ya existe.
  ///
  /// Valida lo MISMO que [addItem] y por la misma razón: hasta que la ficha
  /// se pudo editar, este método no tenía ni un llamador en la interfaz, así
  /// que sus datos nunca pasaban por una comprobación. Ahora entra por aquí
  /// todo lo que el usuario corrige a mano.
  Future<void> updateItem(final InventoryItemEntity item) async {
    if (item.id.isEmpty) {
      throw ArgumentError('No se puede actualizar una ficha sin id');
    }
    final safeName = item.name.trim();
    if (safeName.isEmpty) throw ArgumentError('El nombre es obligatorio');
    if (!item.price.isFinite || item.price < 0) {
      throw ArgumentError('El precio no puede ser negativo');
    }
    if (item.stock < 0 || item.minStock < 0) {
      throw ArgumentError('El stock no puede ser negativo');
    }
    await _repository.updateItem(
      InventoryItemEntity(
        id: item.id,
        name: safeName,
        type: item.type,
        price: item.price,
        stock: item.stock,
        minStock: item.minStock,
        unit: item.unit.trim().isEmpty ? 'unidades' : item.unit.trim(),
        supplier: _opcional(item.supplier),
        code: _opcional(item.code),
      ),
    );
  }

  /// Normaliza un campo opcional: recorta los espacios y convierte lo vacío
  /// en `null`.
  ///
  /// Que sea `null` y no `''` importa en pantalla: la ficha dibuja la línea
  /// "Proveedor" con `supplier != null` y el código con `code != null`, así
  /// que una cadena vacía pintaría una fila con la etiqueta y nada al lado,
  /// y un "Código" seguido de nada.
  static String? _opcional(final String? valor) {
    final texto = valor?.trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  /// Guarda de golpe los artículos confirmados de una boleta.
  ///
  /// Valida LO MISMO que [addItem] y [updateItem], y por el mismo motivo:
  /// estos datos no los escribió el usuario campo a campo, los propuso un
  /// reconocimiento de texto y un modelo, así que son los MENOS fiables que
  /// entran al inventario. Un nombre vacío o un precio infinito aquí
  /// reventarían el lote entero con un error opaco del servidor.
  ///
  /// Un artículo inválido NO se cuela ni se descarta en silencio: se lanza,
  /// y la pantalla de revisión dice qué pasó. Descartarlo guardaría 14 de
  /// 15 fichas diciendo "15 artículos agregados".
  Future<void> applyScannedItems({
    required final List<InventoryItemEntity> nuevos,
    required final Map<String, int> stocksFinales,
    required final Map<String, double> preciosNuevos,
  }) async {
    final limpios = <InventoryItemEntity>[];
    for (final item in nuevos) {
      final safeName = item.name.trim();
      if (safeName.isEmpty) throw ArgumentError('El nombre es obligatorio');
      if (!item.price.isFinite || item.price < 0) {
        throw ArgumentError('El precio no puede ser negativo');
      }
      if (item.stock < 0 || item.minStock < 0) {
        throw ArgumentError('El stock no puede ser negativo');
      }
      limpios.add(
        InventoryItemEntity(
          id: '',
          name: safeName,
          type: item.type,
          price: item.price,
          stock: item.stock,
          minStock: item.minStock,
          unit: item.unit.trim().isEmpty ? 'unidades' : item.unit.trim(),
          supplier: _opcional(item.supplier),
          code: _opcional(item.code),
        ),
      );
    }

    for (final entry in stocksFinales.entries) {
      if (entry.key.isEmpty) {
        throw ArgumentError('No se puede actualizar una ficha sin id');
      }
      if (entry.value < 0) {
        throw ArgumentError('El stock no puede ser negativo');
      }
    }
    for (final entry in preciosNuevos.entries) {
      if (entry.key.isEmpty) {
        throw ArgumentError('No se puede actualizar una ficha sin id');
      }
      if (!entry.value.isFinite || entry.value < 0) {
        throw ArgumentError('El precio no puede ser negativo');
      }
    }

    if (limpios.isEmpty && stocksFinales.isEmpty && preciosNuevos.isEmpty) {
      throw ArgumentError('No hay nada que guardar');
    }

    // ─── EL PRESUPUESTO DEL LOTE ──────────────────────────────────────
    // El datasource manda UN `WriteBatch`, y un lote de Firestore admite
    // 500 operaciones. Hoy no se puede pasar porque el lector topa la
    // boleta en 40 artículos, pero ese tope vive en el parser y el 500
    // vivía en un comentario del datasource: NADA ataba las dos cifras.
    // Subir el tope de la boleta a 600 compilaba, pasaba los tests y
    // reventaba en producción con la boleta entera sin guardar.
    //
    // Se cuenta y se para aquí, antes de abrir el lote. Un error con
    // mensaje propio es peor que guardar, pero mucho mejor que un fallo
    // opaco del servidor; y trocear el lote no es la salida, porque
    // perdería la atomicidad, que es lo que impide el estado de "media
    // boleta guardada" (el usuario no sabe qué mitad le falta y volver a
    // leer la boleta duplicaría la otra).
    final fichasTocadas = {...stocksFinales.keys, ...preciosNuevos.keys};
    final operaciones = limpios.length + fichasTocadas.length;
    if (operaciones > FirestoreLimits.maxBatchWrites) {
      throw ArgumentError(
        'Son $operaciones escrituras y en un lote caben '
        '${FirestoreLimits.maxBatchWrites}',
      );
    }

    await _repository.applyScannedItems(
      nuevos: limpios,
      stocksFinales: stocksFinales,
      preciosNuevos: preciosNuevos,
    );
  }

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

  /// Suscripción al inventario completo.
  ///
  /// Un fallo aquí NO enciende [error] ni cambia [isLoading]: esta lista no
  /// alimenta ninguna pantalla, solo mejora el emparejamiento del lector de
  /// boletas. Si se cae, el lector propone fichas nuevas en vez de sumar
  /// stock —que el usuario ve y corrige— y la pestaña de Inventario sigue
  /// funcionando como si nada. Contaminar el estado de error de la pantalla
  /// con un fallo de algo que ni se dibuja sería peor.
  void _subscribeCompleto() {
    _completoSub?.cancel();
    _completoSub = _repository.watchAllItems().listen(
      (final items) {
        _inventarioCompleto = items;
        _notify();
      },
      onError: (final Object error, final StackTrace stackTrace) {
        debugPrint(
          'InventoryProvider: error en el stream completo: '
          '$error / $stackTrace',
        );
      },
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _itemsSub?.cancel();
    _itemsSub = null;
    _completoSub?.cancel();
    _completoSub = null;
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
