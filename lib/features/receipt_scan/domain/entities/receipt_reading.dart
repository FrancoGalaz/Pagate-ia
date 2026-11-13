// ═══════════════════════════════════════════════════════════════════════
// LO QUE ML KIT DEVOLVIÓ
// ═══════════════════════════════════════════════════════════════════════
// Esta es la frontera entre el reconocimiento de texto (nativo, en el
// dispositivo) y la interpretación (Dart, probable sin Firebase ni
// plugins). Todo lo que hay debajo de esta clase se puede probar con un
// test de unidad escribiendo las líneas a mano, y eso es exactamente lo
// que hacen `test/features/receipt_scan/local_line_item_parser_test.dart` y
// sus vecinos.
//
// `confidence` y `angle` de `TextLine` son anulables en la API de ML Kit
// (verificado en google_mlkit_text_recognition-0.16.0,
// lib/src/text_recognizer.dart:134 y :138). Cuando vienen nulos se tratan
// como "desconocido" y NO se avisa de nada: un aviso de "poca confianza"
// disparado por un campo ausente afirmaría algo que el código no sabe.
// ═══════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

/// Una línea de texto reconocida, con lo mínimo que la heurística necesita.
@immutable
class OcrLine {
  /// Texto tal cual lo devolvió ML Kit, sin normalizar.
  final String text;

  /// Confianza de la línea, de 0 a 1, o `null` si ML Kit no la dio.
  final double? confidence;

  /// Borde superior de la caja de la línea, en píxeles de la imagen. Ordena
  /// las líneas de arriba abajo.
  final double top;

  /// Borde izquierdo de la caja. Es lo que permite saber si una línea sin
  /// precio es la continuación del nombre de la anterior (misma sangría) o
  /// un dato de otra columna.
  final double left;

  /// Alto de la caja, en píxeles de la imagen.
  ///
  /// Lo usa el reensamblado de filas para saber cuánto puede variar el
  /// `top` de dos trozos que están en la misma línea de la boleta: una
  /// tolerancia en píxeles absolutos sería distinta en una foto de 1000 px
  /// y en una de 3000.
  final double height;

  const OcrLine({
    required this.text,
    this.confidence,
    this.top = 0,
    this.left = 0,
    this.height = 0,
  });

  @override
  String toString() => 'OcrLine("$text", top: $top, left: $left)';
}

/// Por qué la lista propuesta puede ser peor de lo normal.
///
/// Se comunica EN PALABRAS en la pantalla de revisión, no solo con un
/// color: el color no puede ser el único portador de la información
/// (WCAG 1.4.1), y además lo que hay que decirle al usuario aquí es qué
/// revisar con más cuidado, que no se deduce de un tono ámbar.
enum ScanDegradation {
  /// El modelo ordenó la lista. Es el caso bueno.
  ninguna,

  /// No hubo red: la lista la ordenó la heurística local.
  sinConexion,

  /// Se agotó la cuota de lecturas ordenadas por el modelo. NO es un error:
  /// la lista local ya está en pantalla y la función sigue funcionando.
  sinCuota,

  /// El modelo falló o devolvió algo irrecuperable: se conserva la local.
  modeloFallo,

  /// El modelo contestó bien pero no sacó ningún artículo del texto.
  modeloVacio,
}

/// El texto de un documento, ya reconocido en el dispositivo.
@immutable
class ReceiptReading {
  /// Líneas aplanadas de todos los bloques, ordenadas por `top` y, a igual
  /// `top`, por `left`.
  final List<OcrLine> lines;

  /// El texto completo, tal como lo devolvió `RecognizedText.text`. Es lo
  /// único que se envía al backend para ordenarlo, y lo único que puede
  /// salir del teléfono en todo este flujo.
  final String rawText;

  /// Páginas leídas. Siempre 1 para una imagen.
  final int pages;

  /// `true` si el documento tenía más páginas de las que se leyeron.
  final bool truncated;

  const ReceiptReading({
    required this.lines,
    required this.rawText,
    this.pages = 1,
    this.truncated = false,
  });

  /// Media de las confianzas que ML Kit informó, o `null` si no informó
  /// ninguna.
  ///
  /// SE CALCULA DE [lines] Y NO SE GUARDA APARTE. Con un campo propio había
  /// dos fuentes para el mismo dato —el campo y las líneas— y nada obligaba
  /// a que coincidieran: un objeto construido a mano con líneas de
  /// confianza 0,2 y el campo sin poner se declaraba "de confianza
  /// desconocida", que es justo lo contrario de lo que decían sus líneas.
  double? get meanConfidence {
    var suma = 0.0;
    var cuantas = 0;
    for (final linea in lines) {
      final c = linea.confidence;
      if (c != null && c.isFinite) {
        suma += c;
        cuantas++;
      }
    }
    return cuantas == 0 ? null : suma / cuantas;
  }

  /// Lectura sin nada. El caso de la foto borrosa o del papel en blanco.
  static const ReceiptReading vacia = ReceiptReading(lines: [], rawText: '');

  bool get estaVacia => rawText.trim().isEmpty;

  /// `true` si la media de confianza es baja de verdad.
  ///
  /// Solo cuando ML Kit la informó: con `meanConfidence == null` esto es
  /// `false`, porque "no lo sé" no es "salió mal".
  bool get confianzaBaja {
    final c = meanConfidence;
    return c != null && c < 0.5;
  }
}
