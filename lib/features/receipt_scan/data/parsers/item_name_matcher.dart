// ═══════════════════════════════════════════════════════════════════════
// EMPAREJAR UN ARTÍCULO LEÍDO CON UNA FICHA QUE YA EXISTE
// ═══════════════════════════════════════════════════════════════════════
// NADA DE EMPAREJAMIENTO APROXIMADO. Es una decisión, no una omisión: un
// parecido mal resuelto suma stock al material equivocado, y eso es peor
// que crear una ficha duplicada, que el usuario ve y borra. Igualdad
// exacta de la cadena normalizada, y se acabó.
//
// SE COMPARA CONTRA LOS DOS TIPOS, productos y materiales. Si el usuario
// tiene "Arcilla gres" como producto porque la revende, la boleta de
// compra tiene que encontrarla igual: lo que el usuario quiere es que el
// stock de ESA ficha suba, no una segunda ficha con el mismo nombre en la
// otra pestaña.
//
// SI COINCIDEN VARIAS GANA LA DE `id` MENOR. No es que sea la mejor: es
// que es DETERMINISTA. Con dos fichas del mismo nombre, el orden del
// stream de Firestore no está garantizado, así que sin un criterio fijo la
// misma boleta sumaría stock a una ficha distinta en cada lectura.
// ═══════════════════════════════════════════════════════════════════════

import '../../../inventory/domain/entities/inventory_item_entity.dart';
import '../../domain/entities/scanned_line_item.dart';

/// Caracteres con tilde o diéresis y su equivalente sin ella.
///
/// Se escribe el mapa en vez de usar una normalización Unicode porque Dart
/// no trae NFD en el núcleo y añadir un paquete para quitar siete tildes no
/// se justifica. Son las del español más la `ü` y la `ñ`.
const Map<String, String> _sinTilde = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

final RegExp _noAlfanumerico = RegExp('[^a-z0-9 ]');
final RegExp _espacios = RegExp(r'\s+');

/// Normaliza un nombre para comparar: minúsculas, sin tildes, sin signos,
/// con los espacios colapsados.
///
/// `ARCILLA  GRES 25kg.` y `Arcilla gres 25kg` dan la misma cadena.
String normalizeForMatch(final String nombre) {
  final minusculas = nombre.toLowerCase();
  final buffer = StringBuffer();
  for (final char in minusculas.split('')) {
    buffer.write(_sinTilde[char] ?? char);
  }
  return buffer
      .toString()
      .replaceAll(_noAlfanumerico, ' ')
      .replaceAll(_espacios, ' ')
      .trim();
}

/// Devuelve [items] con la coincidencia de inventario ya puesta.
///
/// Los que no empareja quedan con [ScanAction.crearFicha] y sin datos de
/// ficha existente; los que sí, con [ScanAction.sumarStock] por defecto,
/// que es lo que un artesano espera al anotar una compra del mismo
/// material.
List<ScannedLineItem> emparejarConInventario(
  final List<ScannedLineItem> items,
  final List<InventoryItemEntity> inventario,
) {
  if (items.isEmpty) return items;

  // Un índice por nombre normalizado, construido una vez: con 40 artículos
  // y un inventario de 500 fichas, comparar uno a uno serían 20.000
  // normalizaciones dentro de lo que el usuario percibe como "leyendo".
  final porNombre = <String, InventoryItemEntity>{};
  for (final ficha in inventario) {
    final clave = normalizeForMatch(ficha.name);
    if (clave.isEmpty) continue;
    final previa = porNombre[clave];
    if (previa == null || ficha.id.compareTo(previa.id) < 0) {
      porNombre[clave] = ficha;
    }
  }

  return [
    for (final item in items)
      _conFicha(item, porNombre[normalizeForMatch(item.name)]),
  ];
}

ScannedLineItem _conFicha(
  final ScannedLineItem item,
  final InventoryItemEntity? ficha,
) {
  if (ficha == null) return item.conCoincidencia();
  return item.conCoincidencia(
    itemId: ficha.id,
    itemName: ficha.name,
    stock: ficha.stock,
    price: ficha.price,
  );
}
