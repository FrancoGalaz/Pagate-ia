// ═══════════════════════════════════════════════════════════════════════
// EL MODELO ORDENA EL TEXTO, Y SI NO PUEDE SE CONSERVA LA LISTA LOCAL
// ═══════════════════════════════════════════════════════════════════════
// Lo difícil no es leer, es interpretar. ML Kit devuelve texto suelto;
// convertir `2 SACOS ARCILLA GRES 25K 18.990` en cantidad, nombre y precio
// es la parte que cuesta, y sobre texto limpio un modelo de TEXTO acierta
// mucho más que una regla. Un modelo de visión cobraría por la imagen y
// además haría peor OCR que ML Kit, que es el de Google corriendo gratis
// en el teléfono.
//
// LA LISTA LOCAL NO SE PIERDE NUNCA. Cualquier fallo del callable —sin
// red, cuota agotada, plazo vencido, salida irrecuperable, o que el
// callable no esté desplegado— devuelve la lista local con la bandera de
// degradación puesta, que la pantalla dice EN PALABRAS. Es la diferencia
// entre una función que se cae en una feria sin señal y una que baja de
// calidad y lo admite.
//
// GUARDA CONTRA ALUCINACIÓN, y no es un descarte. Si el nombre que
// devuelve el modelo no comparte suficientes palabras con el texto del
// OCR, el artículo NO se tira: se marca `notInText`, llega con la casilla
// desmarcada y con la etiqueta que lo dice. Descartarlo en silencio
// perdería lecturas correctas (el modelo expande legítimamente `ARC GRES`
// a `Arcilla gres`); dejarlo marcado violaría "la app propone, el usuario
// confirma".
// ═══════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../../../../core/services/receipt_scan_service.dart';
import '../../domain/entities/receipt_reading.dart';
import '../../domain/entities/scanned_line_item.dart';
import '../../domain/repositories/receipt_scan_repository.dart';
import 'item_name_case.dart';
import 'item_name_matcher.dart';
import 'local_line_item_parser.dart';

/// Proporción mínima de palabras del nombre que tienen que aparecer en el
/// texto del OCR para NO marcar el artículo como inventado.
///
/// 0,6 y no 1,0 porque el modelo normaliza de forma legítima: de
/// `2 SACO ARC GRES 25K` saca "Arcilla gres 25 kg", y de las cuatro
/// palabras de tres letras o más ("arcilla", "gres", "kg") dos aparecen
/// tal cual en el texto.
const double kUmbralDePalabrasEnTexto = 0.6;

/// Longitud mínima de palabra que cuenta para la comprobación. Las de una
/// o dos letras ("de", "x", "kg") aparecen en cualquier texto y no prueban
/// nada.
const int kMinLongitudDePalabra = 3;

final RegExp _palabras = RegExp(r'\s+');

/// Pide al backend que ordene [lectura] y devuelve la lista resultante.
///
/// Nunca lanza: traduce todo fallo a una [StructuredReceipt] con [local]
/// dentro y la degradación correspondiente.
Future<StructuredReceipt> estructurarConElModelo({
  required final ReceiptScanService servicio,
  required final ReceiptReading lectura,
  required final List<ScannedLineItem> local,
  final String? source,
}) async {
  if (lectura.estaVacia) {
    return StructuredReceipt(items: local, degradation: ScanDegradation.ninguna);
  }

  final ScanReceiptResult respuesta;
  try {
    respuesta = await servicio.structure(
      text: lectura.rawText,
      source: source,
    );
  } on ReceiptScanServiceException catch (e) {
    debugPrint('scanReceipt falló (${e.code}): ${e.message}');
    return StructuredReceipt(
      items: local,
      // LA CUOTA AGOTADA SE DISTINGUE DEL RESTO porque no se comunica
      // igual: es información, no un fallo, y el texto que se muestra es el
      // del servidor, que es el único que sabe cuántas lecturas eran.
      degradation:
          e.esCuota ? ScanDegradation.sinCuota : ScanDegradation.modeloFallo,
      serverMessage: e.fromServer ? e.message : null,
    );
  } catch (e) {
    debugPrint('scanReceipt falló de forma inesperada: $e');
    return StructuredReceipt(
      items: local,
      degradation: ScanDegradation.modeloFallo,
    );
  }

  if (respuesta.items.isEmpty) {
    // El modelo contestó bien y no sacó nada. Puede tener razón (una foto
    // de un recibo sin artículos), así que se conserva la lista local y se
    // avisa en vez de dar la lista por buena.
    return StructuredReceipt(
      items: local,
      degradation: ScanDegradation.modeloVacio,
    );
  }

  final palabrasDelTexto = _palabrasUtiles(lectura.rawText);

  // EL PROVEEDOR DEL SERVIDOR MANDA, PERO SI NO LO TRAE SE CONSERVA EL QUE
  // SACÓ LA HEURÍSTICA LOCAL. Los dos leen el MISMO texto, así que no es
  // inventar nada: es no perder un dato que ya se tenía. Sin esto, una
  // respuesta del modelo sin `supplier` borraba el «Ceramicas del sur Ltda»
  // que la cabecera sí decía, y dejaba el campo vacío.
  final proveedor = _primeroNoVacio([
    respuesta.supplier,
    for (final item in local) item.supplier,
  ]);

  final items = <ScannedLineItem>[];
  for (final crudo in respuesta.items) {
    if (items.length >= kMaxArticulosPorBoleta) break;
    items.add(
      ScannedLineItem(
        // La misma caja que por el camino local: el modelo normalmente ya
        // devuelve el nombre bien escrito y `normalizarCajaDeNombre` lo
        // deja intacto, pero si contestara en mayúsculas la lista no
        // quedaría con dos estilos según qué camino la armó.
        name: normalizarCajaDeNombre(_recortarNombre(crudo.name)),
        rawQuantity: crudo.quantity,
        unit: crudo.unit.trim().isEmpty ? 'unidades' : crudo.unit.trim(),
        unitPrice: crudo.unitPrice,
        code: crudo.code,
        supplier: proveedor,
        ambiguous: _eraAmbiguoEnLaLista(local, crudo.name),
        notInText: !_apareceEnElTexto(crudo.name, palabrasDelTexto),
        included: _apareceEnElTexto(crudo.name, palabrasDelTexto),
      ),
    );
  }

  return StructuredReceipt(
    items: items,
    degradation: ScanDegradation.ninguna,
    truncated: respuesta.truncated || respuesta.items.length > items.length,
  );
}

/// Palabras de tres letras o más del texto del OCR, normalizadas.
Set<String> _palabrasUtiles(final String texto) => normalizeForMatch(texto)
    .split(_palabras)
    .where((final p) => p.length >= kMinLongitudDePalabra)
    .toSet();

/// `true` si bastantes palabras del nombre están en el texto reconocido.
bool _apareceEnElTexto(
  final String nombre,
  final Set<String> palabrasDelTexto,
) {
  final palabras = normalizeForMatch(nombre)
      .split(_palabras)
      .where((final p) => p.length >= kMinLongitudDePalabra)
      .toList();

  // Un nombre sin ninguna palabra larga ("Flete", "Kg") no se puede
  // comprobar por este camino, así que se da por bueno: marcar como
  // inventado lo que no se sabe comprobar sería afirmar algo falso.
  if (palabras.isEmpty) return true;

  final presentes = palabras.where(palabrasDelTexto.contains).length;
  return presentes / palabras.length >= kUmbralDePalabrasEnTexto;
}

/// Conserva la marca de ambigüedad que detectó la heurística local.
///
/// El modelo no sabe cuántos montos había en la línea —recibe el texto
/// entero, no línea a línea—, pero la heurística sí lo midió. Si el
/// artículo equivalente salió ambiguo en local, el aviso sigue siendo
/// cierto: en la boleta había un solo monto en esa línea, y el usuario
/// tiene que verlo.
///
/// SE EMPAREJA POR PALABRAS, NO POR IGUALDAD. Comparar las cadenas
/// normalizadas no servía: el modelo normaliza de forma legítima, así que
/// `ARCILLA GRES 25K` y `Arcilla gres 25 kg` son el mismo artículo y dos
/// cadenas distintas, y el aviso de ambigüedad se perdía justo en el caso
/// corriente. Aquí es distinto del emparejamiento con el inventario, que sí
/// exige igualdad exacta: equivocarse allí suma stock al material
/// equivocado, y equivocarse aquí solo pone o quita un aviso.
bool _eraAmbiguoEnLaLista(
  final List<ScannedLineItem> local,
  final String nombre,
) {
  final palabras = _palabrasUtiles(nombre);
  if (palabras.isEmpty) return false;

  var mejorSolape = 0.0;
  var ambiguo = false;
  for (final item in local) {
    final suyas = _palabrasUtiles(item.name);
    if (suyas.isEmpty) continue;
    final comunes = palabras.where(suyas.contains).length;
    final solape = comunes / palabras.length;
    if (solape > mejorSolape) {
      mejorSolape = solape;
      ambiguo = item.ambiguous;
    }
  }
  return mejorSolape >= kUmbralDePalabrasEnTexto && ambiguo;
}

/// El primer valor con algo escrito, o `null` si no hay ninguno.
String? _primeroNoVacio(final List<String?> candidatos) {
  for (final candidato in candidatos) {
    final texto = candidato?.trim() ?? '';
    if (texto.isNotEmpty) return texto;
  }
  return null;
}

String _recortarNombre(final String nombre) {
  final texto = nombre.trim();
  return texto.length > kMaxNombreArticulo
      ? texto.substring(0, kMaxNombreArticulo).trim()
      : texto;
}
