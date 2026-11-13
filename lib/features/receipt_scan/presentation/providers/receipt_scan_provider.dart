import 'package:flutter/foundation.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../inventory/domain/entities/inventory_item_entity.dart';
import '../../../inventory/domain/entities/inventory_item_type.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../data/parsers/item_name_matcher.dart';
import '../../domain/entities/receipt_document.dart';
import '../../domain/entities/receipt_reading.dart';
import '../../domain/entities/scanned_line_item.dart';
import '../../domain/repositories/receipt_scan_repository.dart';

// ═══════════════════════════════════════════════════════════════════════
// ESTADO DE UNA LECTURA DE BOLETA
// ═══════════════════════════════════════════════════════════════════════
// LA LISTA LOCAL SE PUBLICA ANTES DE LLAMAR AL MODELO. No es una
// optimización: es lo que garantiza que si el callable tarda, falla o no
// existe, en pantalla ya hay algo que el usuario puede revisar. El modelo
// REEMPLAZA esa lista solo si contesta con artículos; en cualquier otro
// caso se conserva la local y se enciende la bandera de degradación.
//
// LO QUE SE GUARDA ES LO QUE LA PANTALLA PROMETIÓ. Los stocks finales se
// calculan con el `matchedStock` que el usuario tenía a la vista cuando
// confirmó, no volviendo a leer el inventario en el momento de guardar: si
// el stream reemitió entre la revisión y el toque del botón, guardar otra
// cifra sería escribir algo que nadie aprobó.
// ═══════════════════════════════════════════════════════════════════════

/// Fase de la pantalla de lectura.
enum ReceiptScanPhase {
  /// Reconociendo el texto y ordenando la lista.
  leyendo,

  /// ML Kit no devolvió nada legible.
  sinTexto,

  /// Falló la lectura con un motivo propio (PDF protegido, muy grande...).
  errorDeLectura,

  /// La lista propuesta está en pantalla y el usuario la revisa.
  revisando,

  /// Guardando en el inventario.
  guardando,

  /// Se guardó. La pantalla se cierra.
  guardado,
}

class ReceiptScanProvider extends ChangeNotifier {
  final ReceiptScanRepository _repository;
  final InventoryProvider _inventory;

  ReceiptScanProvider({
    required final ReceiptScanRepository repository,
    required final InventoryProvider inventory,
  })  : _repository = repository,
        _inventory = inventory;

  ReceiptScanPhase _phase = ReceiptScanPhase.leyendo;
  List<ScannedLineItem> _items = const [];
  ScanDegradation _degradation = ScanDegradation.ninguna;
  String? _serverMessage;
  String? _errorMessage;
  String? _errorHint;
  String? _saveError;
  bool _truncated = false;
  bool _confianzaBaja = false;
  int _altas = 0;
  int _actualizadas = 0;
  InventoryItemType? _tipoDeLoGuardado;
  bool _disposed = false;

  // ─── Estado ───────────────────────────────────────────────────────

  ReceiptScanPhase get phase => _phase;
  List<ScannedLineItem> get items => _items;
  ScanDegradation get degradation => _degradation;
  String? get serverMessage => _serverMessage;
  String? get errorMessage => _errorMessage;
  String? get errorHint => _errorHint;
  String? get saveError => _saveError;
  bool get truncated => _truncated;
  bool get confianzaBaja => _confianzaBaja;

  /// Artículos marcados para guardar.
  int get seleccionados => _items.where((final i) => i.included).length;

  /// Fichas NUEVAS que entraron en la última confirmación.
  int get altas => _altas;

  /// Fichas que ya existían y a las que se les sumó stock.
  ///
  /// Se cuentan FICHAS, no líneas de la boleta: dos líneas del mismo
  /// material son una sola ficha actualizada, y decir dos sería contar un
  /// documento que no existe.
  int get actualizadas => _actualizadas;

  /// Pestaña del inventario donde quedó lo que se acaba de guardar, o
  /// `null` si todavía no se ha guardado nada.
  ///
  /// EL DEFECTO QUE ARREGLA, VISTO EN PANTALLA. El usuario abría el lector
  /// desde la pestaña Productos, confirmaba seis materiales y la app lo
  /// devolvía a Productos, que seguía vacía: seis cosas confirmadas y una
  /// lista vacía de ellas delante. Con esto, la pestaña pasa a ser la de lo
  /// que acaba de guardar.
  InventoryItemType? get tipoDeLoGuardado => _tipoDeLoGuardado;

  /// Lo que se le dice al usuario cuando el guardado salió bien.
  ///
  /// EL RECUENTO DICE LA VERDAD, y antes no. El mensaje era
  /// "6 artículos agregados al inventario" contando las líneas marcadas,
  /// pero de esas seis cinco eran altas y una era stock sumado a una ficha
  /// que ya existía: en el inventario entraron CINCO fichas. Un recuento
  /// que no cuadra con lo que el usuario ve después es exactamente lo que
  /// le hace desconfiar de la lectura entera.
  ///
  /// `null` mientras no haya nada guardado.
  String? get mensajeDeLoGuardado {
    if (_altas == 0 && _actualizadas == 0) return null;

    if (_actualizadas == 0) {
      return _altas == 1
          ? '1 artículo agregado al inventario.'
          : '$_altas artículos agregados al inventario.';
    }
    if (_altas == 0) {
      return _actualizadas == 1
          ? 'Le sumé stock a 1 ficha que ya tenías.'
          : 'Le sumé stock a $_actualizadas fichas que ya tenías.';
    }
    final nuevas = _altas == 1 ? '1 ficha nueva' : '$_altas fichas nuevas';
    final viejas = _actualizadas == 1
        ? '1 que ya tenías'
        : '$_actualizadas que ya tenías';
    return 'Agregué $nuevas y le sumé stock a $viejas.';
  }

  /// `true` si hay algo que el usuario pueda perder al salir.
  bool get hayTrabajoQuePerder =>
      _phase == ReceiptScanPhase.revisando && _items.isNotEmpty;

  // ─── Lectura ──────────────────────────────────────────────────────

  /// Lee [documento], ordena la lista y deja la pantalla en revisión.
  ///
  /// Nunca lanza: todo fallo acaba en una fase con mensaje. El documento se
  /// borra dentro de [ReceiptScanRepository.leer], también si falla.
  Future<void> procesar(final ReceiptDocument documento) async {
    _phase = ReceiptScanPhase.leyendo;
    _items = const [];
    _degradation = ScanDegradation.ninguna;
    _serverMessage = null;
    _errorMessage = null;
    _errorHint = null;
    _saveError = null;
    _truncated = false;
    _confianzaBaja = false;
    _notify();

    final ReceiptReading lectura;
    try {
      lectura = await _repository.leer(documento);
    } on ReceiptScanException catch (e) {
      _phase = ReceiptScanPhase.errorDeLectura;
      _errorMessage = e.message;
      _errorHint = e.hint;
      _notify();
      return;
    } catch (e, st) {
      debugPrint('ReceiptScanProvider: fallo inesperado al leer: $e\n$st');
      _phase = ReceiptScanPhase.errorDeLectura;
      _errorMessage = 'No pude leer ese archivo.';
      _errorHint = 'Prueba con una foto de la boleta impresa.';
      _notify();
      return;
    }

    if (lectura.estaVacia) {
      _phase = ReceiptScanPhase.sinTexto;
      _notify();
      return;
    }

    _confianzaBaja = lectura.confianzaBaja;

    final local = _repository.parseLocal(lectura);
    _truncated = local.truncated || lectura.truncated;

    // Rastro mínimo para diagnosticar la próxima vez que la lectura salga
    // rara. NO lleva el texto de la boleta: un volcado del contenido en el
    // registro del dispositivo sería justo lo que la política de privacidad
    // dice que no pasa. Solo los recuentos.
    debugPrint(
      'ReceiptScan: ${lectura.lines.length} líneas de OCR, '
      '${local.items.length} artículos propuestos',
    );

    // La lista local se publica YA, antes de llamar al modelo.
    _items = emparejarConInventario(local.items, _inventory.inventarioCompleto);
    _phase = ReceiptScanPhase.revisando;
    _notify();

    final StructuredReceipt estructurada;
    try {
      estructurada = await _repository.structure(
        lectura: lectura,
        local: local.items,
        esPdf: documento.esPdf,
      );
    } catch (e, st) {
      // `structure` promete no lanzar, pero si un día lo hiciera la lista
      // local tiene que sobrevivir igual: es la única copia que hay.
      debugPrint('ReceiptScanProvider: structure lanzó: $e\n$st');
      _degradation = ScanDegradation.modeloFallo;
      _notify();
      return;
    }
    if (_disposed) return;

    _degradation = estructurada.degradation;
    _serverMessage = estructurada.serverMessage;
    _truncated = _truncated || estructurada.truncated;

    // Solo se reemplaza la lista si el modelo trajo artículos. Con la lista
    // vacía se conserva la local, que es la razón de que exista.
    if (estructurada.items.isNotEmpty &&
        !identical(estructurada.items, local.items)) {
      _items = emparejarConInventario(
        estructurada.items,
        _inventory.inventarioCompleto,
      );
    }
    _notify();
  }

  /// Vuelve a intentar con lo que ya hay. No reabre la cámara: eso lo hace
  /// la pantalla, porque el documento viejo ya no existe.
  void reiniciar() {
    _phase = ReceiptScanPhase.leyendo;
    _notify();
  }

  // ─── Revisión ─────────────────────────────────────────────────────

  void alternar(final int indice, {final bool? valor}) {
    if (indice < 0 || indice >= _items.length) return;
    final item = _items[indice];
    _reemplazar(indice, item.copyWith(included: valor ?? !item.included));
  }

  /// Sustituye el artículo [indice] por la versión que el usuario corrigió.
  ///
  /// SI CAMBIÓ EL NOMBRE, SE VUELVE A EMPAREJAR, y eso no es un extra: es el
  /// caso corriente. El OCR saca `CAOLIN BLANCO 10.20O`, que no empareja con
  /// nada; el usuario lo corrige a `Caolín`, que SÍ es una ficha que ya
  /// tiene. Sin volver a mirar, la pantalla seguía diciendo "ficha nueva" y
  /// guardaba un duplicado del material que el usuario acababa de nombrar
  /// igual. Visto en emulator-5554: quedaron `Caolín` con 18 kg y `Caolin`
  /// con 3 kg, dos fichas del mismo material.
  ///
  /// Si el nombre NO cambió se respeta lo que venga, incluido un
  /// [ScanAction.crearFicha] elegido a mano: volver a emparejar ahí
  /// desharía la decisión del usuario.
  void reemplazar(final int indice, final ScannedLineItem item) {
    if (indice < 0 || indice >= _items.length) return;

    final anterior = _items[indice];
    if (normalizeForMatch(anterior.name) == normalizeForMatch(item.name)) {
      _reemplazar(indice, item);
      return;
    }

    // La intención se reinicia a "sumar al stock" antes de emparejar: el
    // `crearFicha` que llevaba el artículo no lo eligió el usuario, se lo
    // puso el emparejamiento anterior por no encontrar nada. Conservarlo
    // dejaba la ficha encontrada a la vista y seguía guardando un duplicado.
    // `emparejarConInventario` vuelve a poner `crearFicha` si el nombre
    // nuevo tampoco empareja.
    _reemplazar(
      indice,
      emparejarConInventario(
        [item.copyWith(action: ScanAction.sumarStock)],
        _inventory.inventarioCompleto,
      ).single,
    );
  }

  void _reemplazar(final int indice, final ScannedLineItem item) {
    final copia = [..._items];
    copia[indice] = item;
    _items = copia;
    _notify();
  }

  // ─── Guardado ─────────────────────────────────────────────────────

  /// Escribe en el inventario lo que el usuario confirmó.
  ///
  /// Devuelve `true` si entró todo. Ante un fallo deja el mensaje en
  /// [saveError] y la pantalla vuelve a revisión con la lista intacta: la
  /// revisión a mano de doce artículos no se puede perder por un error de
  /// red.
  Future<bool> guardar() async {
    if (_phase == ReceiptScanPhase.guardando) return false;

    final elegidos = _items.where((final i) => i.included).toList();
    if (elegidos.isEmpty) return false;

    // El recuento del intento ANTERIOR se borra aquí, no al final: si este
    // guardado falla, `mensajeDeLoGuardado` tiene que quedar en `null` en
    // vez de anunciar lo que entró la vez pasada.
    _altas = 0;
    _actualizadas = 0;
    _tipoDeLoGuardado = null;

    _phase = ReceiptScanPhase.guardando;
    _saveError = null;
    _notify();

    final nuevos = <InventoryItemEntity>[];
    final stocks = <String, int>{};
    final precios = <String, double>{};

    for (final item in elegidos) {
      final id = item.matchedItemId;
      if (id != null && item.action == ScanAction.sumarStock) {
        // Si dos líneas de la misma boleta apuntan a la misma ficha, las
        // dos cantidades se acumulan sobre el stock que había. Sin esto la
        // segunda sobrescribiría a la primera y se perdería material.
        final base = stocks[id] ?? item.matchedStock ?? 0;
        stocks[id] = base + item.quantity;
        if (item.updatePrice) precios[id] = item.unitPrice;
        continue;
      }
      nuevos.add(
        InventoryItemEntity(
          id: '',
          name: item.name,
          type: item.type,
          price: item.unitPrice,
          stock: item.quantity,
          // 1, igual que el formulario manual: el escáner no sabe cuánto
          // quiere mantener el usuario como mínimo, y poner la cantidad
          // comprada marcaría la ficha como "bajo el mínimo" en el acto.
          minStock: 1,
          unit: item.unit,
          supplier: item.supplier,
          code: item.code,
        ),
      );
    }

    try {
      await _inventory.applyScannedItems(
        nuevos: nuevos,
        stocksFinales: stocks,
        preciosNuevos: precios,
      );
      _altas = nuevos.length;
      _actualizadas = stocks.length;
      _tipoDeLoGuardado = _pestanaDondeQuedo(elegidos);
      _phase = ReceiptScanPhase.guardado;
      _notify();
      return true;
    } catch (e) {
      _phase = ReceiptScanPhase.revisando;
      _saveError = describeDataError(
        e,
        operation: DataOperation.write,
        fallback: 'No se pudieron guardar los artículos',
      );
      _notify();
      return false;
    }
  }

  /// En qué pestaña del inventario quedó la mayor parte de lo guardado.
  ///
  /// Una boleta puede traer de los dos tipos (el usuario cambia el tipo de
  /// una línea en la hoja de revisión), así que no hay una respuesta única:
  /// se elige la pestaña donde quedó MÁS cosa. Con empate manda la del
  /// primer artículo confirmado, que es el primero de la boleta: es un
  /// criterio determinista, y sin uno la misma lectura llevaría a una
  /// pestaña distinta cada vez según el orden del recorrido.
  static InventoryItemType _pestanaDondeQuedo(
    final List<ScannedLineItem> elegidos,
  ) {
    var productos = 0;
    var materiales = 0;
    for (final item in elegidos) {
      if (item.tipoResultante == InventoryItemType.product) {
        productos++;
      } else {
        materiales++;
      }
    }
    if (productos > materiales) return InventoryItemType.product;
    if (materiales > productos) return InventoryItemType.material;
    return elegidos.first.tipoResultante;
  }

  void limpiarErrorDeGuardado() {
    if (_saveError == null) return;
    _saveError = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Tipos que la hoja de revisión ofrece. Vive aquí para que la pantalla no
  /// importe el enum del inventario por su cuenta.
  static const List<InventoryItemType> tipos = InventoryItemType.values;
}
