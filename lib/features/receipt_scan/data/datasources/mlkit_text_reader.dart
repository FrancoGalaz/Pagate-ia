// ═══════════════════════════════════════════════════════════════════════
// RECONOCIMIENTO DE TEXTO EN EL DISPOSITIVO
// ═══════════════════════════════════════════════════════════════════════
// Aquí ocurre la promesa entera de privacidad de esta función: la imagen
// se abre, se le saca el texto y se borra. No sube a ningún servidor, no
// se copia a ninguna carpeta durable y no hace falta conexión.
//
// EL `finally` NO ES DEFENSIVO, ES LA FUNCIÓN. Si el archivo temporal se
// queda, lo que miente no es un formulario: es la política de privacidad
// publicada en la landing, que afirma «la imagen no se guarda». Por eso el
// borrado está en un `finally` que cubre también el PNG intermedio del PDF
// y el cierre del reconocedor, y por eso [leer] no tiene ni un `return`
// que se salte ese bloque.
//
// UN PDF NO SE LEE, SE RASTERIZA. No se busca su capa de texto en ningún
// momento, y eso es deliberado: así un PDF generado digitalmente (la
// boleta electrónica chilena) y uno escaneado siguen EL MISMO camino, que
// es un solo camino que probar. Se usa `Printing.raster`, que en Android
// rasteriza con `android.graphics.pdf.PdfRenderer` —del propio sistema
// operativo— así que no entra ni un byte nativo nuevo, ni un permiso, ni
// una petición de red. Verificado leyendo el plugin en el caché de pub:
//   printing-5.14.3/android/src/.../PrintingJob.java:26  import PdfRenderer
//   printing-5.14.3/android/src/.../PrintingJob.java:424 void rasterPdf(...)
// y su manifiesto solo aporta un `FileProvider`, así que usar `raster` no
// cambia nada del manifiesto fusionado.
//
// HAY QUE PASAR POR PNG. `InputImageFormat` de ML Kit tiene cinco valores
// (`nv21`, `yv12`, `yuv_420_888`, `yuv420`, `bgra8888`) y NINGUNO es
// `rgba8888`, que es el formato de los píxeles crudos de `PdfRaster`
// (printing-5.14.3/lib/src/raster.dart:36). Así que no se puede usar
// `InputImage.fromBytes`: se convierte a PNG con `PdfRaster.toPng()`, se
// escribe un archivo temporal y se usa `InputImage.fromFilePath`.
// ═══════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../domain/entities/receipt_document.dart';
import '../../domain/entities/receipt_reading.dart';
import '../../domain/repositories/receipt_scan_repository.dart';

/// Páginas de un PDF que se leen.
///
/// Dos y no todas: una boleta de compra chilena cabe en una o dos páginas,
/// y rasterizar un PDF de cien a 200 ppp se llevaría la memoria del
/// proceso. Si tenía más, se dice en pantalla; no se supone.
const int kMaxPaginasDePdf = 2;

/// Resolución del rasterizado, en puntos por pulgada.
///
/// 200 ppp sobre una carta da unos 1700×2200 px, que es la resolución a la
/// que ML Kit lee bien un cuerpo de 8 puntos. Subir a 300 cuadruplica la
/// memoria del bitmap sin mejorar el reconocimiento de un texto generado
/// digitalmente.
const double kPpp = 200;

/// Páginas rasterizadas y si el PDF tenía más de las que se leyeron.
class _Rasterizado {
  final List<String> rutas;
  final bool habiaMas;

  const _Rasterizado(this.rutas, {required this.habiaMas});
}

/// Lee el texto de una imagen o de un PDF, en el dispositivo.
class MlkitTextReader {
  /// Inyectable para los tests: devuelve el directorio donde se escribe el
  /// PNG intermedio.
  final Future<Directory> Function() _directorioTemporal;

  MlkitTextReader({final Future<Directory> Function()? directorioTemporal})
      : _directorioTemporal = directorioTemporal ?? getTemporaryDirectory;

  Future<ReceiptReading> leer(final ReceiptDocument documento) async {
    final temporales = <String>[];
    TextRecognizer? reconocedor;
    try {
      final archivo = File(documento.path);
      if (!archivo.existsSync()) {
        throw const ReceiptScanException(
          'archivo-ausente',
          'El archivo ya no está donde lo dejó el sistema.',
          hint: 'Vuelve a intentarlo con la foto o el documento.',
        );
      }

      if (!documento.esLegible) {
        throw ReceiptScanException(
          'tipo-no-soportado',
          'Puedo leer fotos y archivos PDF, y eso es un ${documento.mimeType}.',
          hint: 'Saca una foto de la boleta impresa.',
        );
      }

      final bytes = await archivo.length();
      if (bytes > ReceiptDocument.maxBytes) {
        throw ReceiptScanException(
          'demasiado-grande',
          'Ese archivo pesa ${_enMegas(bytes)} y el tope son 10 MB.',
          hint: 'Saca una foto de la boleta en vez de enviar el archivo '
              'completo, o comparte solo la página con los artículos.',
        );
      }

      final _Rasterizado paginasAleer = documento.esPdf
          ? await _rasterizarPdf(archivo, temporales)
          : _Rasterizado([documento.path], habiaMas: false);

      reconocedor = TextRecognizer();
      final reconocidas = <RecognizedText>[];
      for (final ruta in paginasAleer.rutas) {
        reconocidas.add(
          await reconocedor.processImage(InputImage.fromFilePath(ruta)),
        );
      }

      return _componer(reconocidas, truncado: paginasAleer.habiaMas);
    } finally {
      // Orden: primero el reconocedor (suelta el bitmap nativo), después
      // los archivos. Al revés, en Android el reconocedor puede tener el
      // descriptor abierto y el borrado falla en silencio.
      await reconocedor?.close();
      for (final ruta in temporales) {
        await _borrar(ruta);
      }
      await documento.borrar();
    }
  }

  /// Rasteriza las primeras páginas y devuelve las rutas de los PNG.
  Future<_Rasterizado> _rasterizarPdf(
    final File pdf,
    final List<String> temporales,
  ) async {
    // `canRaster` se consulta ANTES de leer el archivo: en una plataforma
    // sin rasterizado (web, o un Android recortado) `Printing.raster`
    // devuelve un stream que no emite nada, y sin esta comprobación el
    // usuario vería "no pude leer nada de esa imagen", que es falso y le
    // haría repetir la foto para nada.
    final info = await Printing.info();
    if (!info.canRaster) {
      throw const ReceiptScanException(
        'sin-rasterizado',
        'Este teléfono no puede abrir archivos PDF.',
        hint: 'Saca una foto de la boleta impresa.',
      );
    }

    final datos = await pdf.readAsBytes();
    final directorio = await _directorioTemporal();
    final rutas = <String>[];
    var habiaMas = false;

    try {
      // SE PIDEN TODAS LAS PÁGINAS Y SE CONSUMEN DOS, en vez de pedir
      // `pages: [0, 1]`. Es la diferencia entre saber y suponer: con dos
      // páginas pedidas, recibir dos no dice si había una tercera, así que
      // avisar de "leí solo las dos primeras" sería falso en un PDF de dos
      // páginas. Pidiéndolas todas, la tercera emisión ES la prueba de que
      // sobraba, y el `break` corta ahí: el rasterizado es perezoso, así
      // que las demás no se llegan a convertir.
      var indice = 0;
      await for (final pagina in Printing.raster(datos, dpi: kPpp)) {
        if (indice >= kMaxPaginasDePdf) {
          habiaMas = true;
          break;
        }
        final png = await pagina.toPng();
        final ruta = '${directorio.path}/pagate_boleta_${_marca()}_$indice.png';
        await File(ruta).writeAsBytes(png, flush: true);
        temporales.add(ruta);
        rutas.add(ruta);
        indice++;
      }
    } catch (e) {
      // UN PDF PROTEGIDO CON CONTRASEÑA LLEGA AQUÍ. `PdfRenderer` lanza
      // `SecurityException` en el hilo de `rasterPdf`, y el plugin lo
      // propaga a Dart por su manejador de excepciones no capturadas. El
      // mensaje tiene que decir qué hacer, porque el usuario no puede
      // quitarle la contraseña a la boleta de su proveedor.
      debugPrint('No se pudo rasterizar el PDF: $e');
      throw const ReceiptScanException(
        'pdf-protegido',
        'No pude abrir ese PDF. Puede estar protegido con contraseña o '
            'estar dañado.',
        hint: 'Saca una foto de la boleta impresa.',
      );
    }

    if (rutas.isEmpty) {
      throw const ReceiptScanException(
        'pdf-vacio',
        'Ese PDF no tiene ninguna página que pueda leer.',
        hint: 'Saca una foto de la boleta impresa.',
      );
    }
    return _Rasterizado(rutas, habiaMas: habiaMas);
  }

  /// Aplana los bloques de todas las páginas en una sola lista de líneas.
  ReceiptReading _componer(
    final List<RecognizedText> paginas, {
    required final bool truncado,
  }) {
    final lineas = <OcrLine>[];
    final textos = <String>[];

    // El desplazamiento vertical acumulado hace que la página 2 se ordene
    // DESPUÉS de la 1: las cajas de cada página empiezan otra vez en y=0,
    // así que sin esto las líneas de las dos páginas se entrelazarían y la
    // continuación de un nombre acabaría pegada al artículo de otra hoja.
    var desplazamiento = 0.0;

    for (final pagina in paginas) {
      textos.add(pagina.text);
      var maximo = desplazamiento;
      for (final bloque in pagina.blocks) {
        for (final linea in bloque.lines) {
          lineas.add(
            OcrLine(
              text: linea.text,
              confidence: linea.confidence,
              top: linea.boundingBox.top + desplazamiento,
              left: linea.boundingBox.left,
              height: linea.boundingBox.height,
            ),
          );
          final fondo = linea.boundingBox.bottom + desplazamiento;
          if (fondo > maximo) maximo = fondo;
        }
      }
      desplazamiento = maximo + 1;
    }

    return ReceiptReading(
      lines: lineas,
      rawText: textos.join('\n'),
      pages: paginas.length,
      truncated: truncado,
    );
  }

  static String _enMegas(final int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';

  static String _marca() => DateTime.now().microsecondsSinceEpoch.toString();

  static Future<void> _borrar(final String ruta) async {
    try {
      final archivo = File(ruta);
      if (archivo.existsSync()) await archivo.delete();
    } catch (e) {
      debugPrint('MlkitTextReader: no se pudo borrar $ruta: $e');
    }
  }
}
