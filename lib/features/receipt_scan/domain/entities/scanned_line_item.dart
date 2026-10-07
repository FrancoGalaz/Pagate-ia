// ═══════════════════════════════════════════════════════════════════════
// UN ARTÍCULO PROPUESTO
// ═══════════════════════════════════════════════════════════════════════
// LA APP PROPONE, EL USUARIO CONFIRMA. Esta clase es la propuesta, no el
// hecho: lleva dentro tanto lo que se leyó como lo que el usuario decidió
// sobre lo leído ([included], [action], [updatePrice]). Es inmutable y se
// cambia con [copyWith], así que la pantalla de revisión nunca muta un
// artículo a medias y el provider puede comparar estados.
//
// LAS BANDERAS NO SON ADORNOS. [ambiguous] y [notInText] son las dos
// formas en que esta lista puede estar equivocada, y las dos se dicen en
// pantalla en vez de esconderse. Fingir que se entendió es el único fallo
// que esta función no se puede permitir: lo que entra aquí acaba en el
// inventario del usuario.
// ═══════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../../../inventory/domain/entities/inventory_item_type.dart';

/// Qué hacer con un artículo que ya tiene ficha en el inventario.
enum ScanAction {
  /// Crear una ficha nueva, aunque exista otra con el mismo nombre.
  crearFicha,

  /// Sumar la cantidad leída al stock de la ficha que ya existe. Es el
  /// valor por defecto cuando hay coincidencia exacta de nombre.
  sumarStock,
}

@immutable
class ScannedLineItem {
  /// Nombre, ya limpio de cantidades y de montos. Tope 120 caracteres en el
  /// parser; el formulario de revisión permite hasta 200, que es el tope de
  /// `firestore.rules`.
  final String name;

  /// Cantidad tal como salió del texto, que puede ser fraccionaria
  /// (`2,5 kg`). Lo que se guarda es [quantity], el entero.
  final double rawQuantity;

  final String unit;

  /// Precio POR UNIDAD, no total de línea. Ver [ambiguous].
  final double unitPrice;

  /// Código del artículo si se leyó.
  final String? code;

  /// Proveedor de la boleta. Es el mismo para todos los artículos de un
  /// documento, pero vive en el artículo porque es lo que se escribe en su
  /// ficha.
  final String? supplier;

  /// `material` por defecto: una boleta de compra es casi siempre insumos.
  /// El usuario lo cambia en la hoja de revisión.
  final InventoryItemType type;

  /// En la línea había un solo monto y se tomó como precio unitario.
  ///
  /// Es la decisión que más se puede equivocar y por eso se marca:
  /// `2 SACOS ARCILLA GRES 25K 18.990` en un punto de venta chileno
  /// significa cantidad · descripción · precio_unitario, y el total de
  /// línea va en una columna de la derecha que el OCR pierde a menudo.
  /// Tomarlo como total daría $9.495 el saco, un error del doble.
  final bool ambiguous;

  /// El nombre no se encontró en el texto del OCR.
  ///
  /// NO se descarta el artículo: el modelo expande legítimamente
  /// `ARC GRES` a `Arcilla gres`, y descartarlo en silencio perdería
  /// lecturas correctas. Llega con la casilla DESMARCADA y con la etiqueta
  /// que lo dice.
  final bool notInText;

  /// Marcado para guardar. Lo cambia el usuario con la casilla.
  final bool included;

  /// Qué hacer si ya existe. Solo tiene efecto cuando [matches].
  final ScanAction action;

  /// Id de la ficha que empareja por nombre normalizado, o `null`.
  final String? matchedItemId;

  /// Nombre de la ficha que empareja, tal como está guardado.
  final String? matchedName;

  /// Stock actual de la ficha que empareja.
  final int? matchedStock;

  /// Precio guardado de la ficha que empareja.
  final double? matchedPrice;

  /// Sobrescribir el precio guardado con el de la boleta.
  ///
  /// APAGADO POR DEFECTO, y es una decisión de producto, no un descuido: el
  /// precio guardado de un producto es a cuánto lo VENDE el usuario, y
  /// sobrescribirlo con un precio de compra le rompe sus propias finanzas
  /// en silencio.
  final bool updatePrice;

  const ScannedLineItem({
    required this.name,
    required this.rawQuantity,
    required this.unit,
    required this.unitPrice,
    this.code,
    this.supplier,
    this.type = InventoryItemType.material,
    this.ambiguous = false,
    this.notInText = false,
    this.included = true,
    this.action = ScanAction.sumarStock,
    this.matchedItemId,
    this.matchedName,
    this.matchedStock,
    this.matchedPrice,
    this.updatePrice = false,
  });

  /// Lo que entra a Firestore.
  ///
  /// REDONDEA HACIA ARRIBA. `isCount(v)` de `firestore.rules` exige
  /// `v is int` y `stock`/`minStock` son `int` en `InventoryItemEntity`, así
  /// que una cantidad fraccionaria del OCR tiene que volverse entera en
  /// algún punto. Se hace hacia arriba y la hoja de revisión lo dice con
  /// palabras: redondear hacia abajo "pierde" material que el usuario sí
  /// compró. Pasar `stock` a decimal es un cambio de contrato que este
  /// carril no hace; queda anotado en docs/ARQUITECTURA.md.
  int get quantity {
    if (!rawQuantity.isFinite || rawQuantity <= 0) return 1;
    return rawQuantity.ceil();
  }

  /// `true` si el OCR leyó una cantidad con decimales.
  bool get tieneCantidadFraccionaria =>
      rawQuantity.isFinite && rawQuantity != rawQuantity.roundToDouble();

  /// Total de la línea CON la cantidad que se va a guardar, no con la del
  /// OCR: la cifra que se muestra tiene que ser la consecuencia real.
  double get lineTotal => quantity * unitPrice;

  /// `true` si hay una ficha en el inventario con el mismo nombre.
  bool get matches => matchedItemId != null;

  /// Stock final de la ficha emparejada si se suma.
  int? get stockResultante {
    final actual = matchedStock;
    if (actual == null) return null;
    return actual + quantity;
  }

  /// `true` si hay precio guardado y es distinto del de la boleta.
  bool get precioDifiere {
    final guardado = matchedPrice;
    if (guardado == null) return false;
    return (guardado - unitPrice).abs() >= 1;
  }

  ScannedLineItem copyWith({
    final String? name,
    final double? rawQuantity,
    final String? unit,
    final double? unitPrice,
    final String? code,
    final bool limpiarCode = false,
    final String? supplier,
    final bool limpiarSupplier = false,
    final InventoryItemType? type,
    final bool? ambiguous,
    final bool? notInText,
    final bool? included,
    final ScanAction? action,
    final bool? updatePrice,
  }) =>
      ScannedLineItem(
        name: name ?? this.name,
        rawQuantity: rawQuantity ?? this.rawQuantity,
        unit: unit ?? this.unit,
        unitPrice: unitPrice ?? this.unitPrice,
        // Los dos opcionales necesitan una bandera para poder VACIARSE: con
        // `code ?? this.code` un `null` significa "déjalo como estaba", así
        // que borrar el código de un artículo en la hoja de revisión era
        // imposible. Es el mismo defecto que `item_form_sheet.dart` evitó
        // construyendo la entidad a mano en vez de con `copyWith`.
        code: limpiarCode ? null : (code ?? this.code),
        supplier: limpiarSupplier ? null : (supplier ?? this.supplier),
        type: type ?? this.type,
        ambiguous: ambiguous ?? this.ambiguous,
        notInText: notInText ?? this.notInText,
        included: included ?? this.included,
        action: action ?? this.action,
        matchedItemId: matchedItemId,
        matchedName: matchedName,
        matchedStock: matchedStock,
        matchedPrice: matchedPrice,
        updatePrice: updatePrice ?? this.updatePrice,
      );

  /// Devuelve una copia con la coincidencia de inventario puesta o quitada.
  ScannedLineItem conCoincidencia({
    final String? itemId,
    final String? itemName,
    final int? stock,
    final double? price,
  }) =>
      ScannedLineItem(
        name: name,
        rawQuantity: rawQuantity,
        unit: unit,
        unitPrice: unitPrice,
        code: code,
        supplier: supplier,
        type: type,
        ambiguous: ambiguous,
        notInText: notInText,
        included: included,
        action: itemId == null ? ScanAction.crearFicha : action,
        matchedItemId: itemId,
        matchedName: itemName,
        matchedStock: stock,
        matchedPrice: price,
        updatePrice: updatePrice,
      );

  @override
  String toString() => 'ScannedLineItem($name, $rawQuantity $unit, '
      '$unitPrice${ambiguous ? ', ambiguo' : ''}'
      '${notInText ? ', fuera del texto' : ''})';
}
