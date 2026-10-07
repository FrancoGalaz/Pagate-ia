// ═══════════════════════════════════════════════════════════════════════
// EL DOCUMENTO QUE SE VA A LEER
// ═══════════════════════════════════════════════════════════════════════
// Las tres entradas (cámara del sistema, galería del sistema y archivo
// compartido desde otra app) acaban en este mismo objeto, y a partir de
// aquí el camino es único. Es lo que permite que haya UNA pantalla de
// resultado y no tres.
//
// NO GUARDA LA IMAGEN, GUARDA LA RUTA. El archivo es temporal en los tres
// casos: `image_picker` escribe en la caché de la app y
// `receive_sharing_intent` documenta que «all files are copied to a temp
// cache folder». Este objeto es la referencia a algo que está a punto de
// desaparecer, y [borrar] es la operación que cierra la promesa de la
// política de privacidad: la imagen no se queda en ningún sitio.
// ═══════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/foundation.dart';

/// De dónde salió el documento. Solo se usa para el registro y para matizar
/// el mensaje de error: el camino de lectura es el mismo para las cuatro.
enum ReceiptScanSource {
  /// Foto tomada con la cámara del sistema (`ACTION_IMAGE_CAPTURE`).
  camara,

  /// Imagen elegida con el selector de fotos del sistema.
  galeria,

  /// Archivo elegido con el selector de documentos del sistema: un PDF en
  /// Descargas, la boleta que llegó por correo y se bajó al teléfono. En
  /// Android es el marco de acceso al almacenamiento
  /// (`ACTION_OPEN_DOCUMENT`), que no exige ningún permiso.
  archivo,

  /// Archivo compartido a Págate desde WhatsApp, el correo u otra app.
  compartido,
}

/// Un archivo listo para leer: imagen o PDF.
@immutable
class ReceiptDocument {
  /// Ruta del archivo temporal. No se guarda en ningún sitio durable.
  final String path;

  /// Tipo MIME tal como lo dio el sistema, o deducido de la extensión.
  final String mimeType;

  final ReceiptScanSource source;

  const ReceiptDocument({
    required this.path,
    required this.mimeType,
    required this.source,
  });

  /// Tope duro de tamaño. Por encima no se intenta leer.
  ///
  /// No es un número redondo por gusto: una foto de 12 Mpx de un teléfono
  /// corriente pesa entre 3 y 6 MB, así que 10 MB deja holgura para una
  /// boleta larga escaneada a buena resolución y corta antes de que
  /// rasterizar un PDF de cien páginas se lleve la memoria del proceso.
  static const int maxBytes = 10 * 1024 * 1024;

  bool get esPdf => mimeType.toLowerCase() == 'application/pdf';

  bool get esImagen => mimeType.toLowerCase().startsWith('image/');

  /// `true` si el tipo es uno de los dos que la app sabe leer.
  bool get esLegible => esPdf || esImagen;

  /// Deduce el MIME de la extensión cuando el sistema no lo dice.
  ///
  /// `receive_sharing_intent` deja `mimeType` en `null` con bastante
  /// frecuencia en Android —depende de lo que declare la app que comparte—
  /// y sin esto una boleta compartida desde Archivos se descartaría por
  /// "tipo no soportado" aunque sea un PDF perfectamente legible.
  static String mimeDeLaExtension(final String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.pdf')) return 'application/pdf';
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.heic') || p.endsWith('.heif')) return 'image/heic';
    if (p.endsWith('.bmp')) return 'image/bmp';
    return 'application/octet-stream';
  }

  /// Borra el archivo. Se llama SIEMPRE, haya ido bien o mal la lectura.
  ///
  /// Nunca lanza: si el archivo ya no está, o el sistema no deja borrarlo,
  /// el fallo se registra y no se interrumpe el flujo. Lo que no puede
  /// pasar es que una excepción al borrar oculte el resultado de la
  /// lectura, pero tampoco que el borrado se salte en silencio: la política
  /// de privacidad publicada afirma que la imagen no se guarda.
  Future<void> borrar() async {
    try {
      final archivo = File(path);
      if (archivo.existsSync()) await archivo.delete();
    } catch (e) {
      debugPrint('ReceiptDocument: no se pudo borrar $path: $e');
    }
  }

  @override
  String toString() =>
      'ReceiptDocument(${source.name}, $mimeType, ${path.split('/').last})';
}
