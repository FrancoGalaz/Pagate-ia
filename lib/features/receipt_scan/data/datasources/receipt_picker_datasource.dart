// ═══════════════════════════════════════════════════════════════════════
// LA CÁMARA Y LA GALERÍA, SIEMPRE LAS DEL SISTEMA
// ═══════════════════════════════════════════════════════════════════════
// POR QUÉ NO HAY VISTA PREVIA DENTRO DE LA APP. Una vista previa propia
// exige el permiso `android.permission.CAMERA`, que sale en la ficha de
// Google Play y que hay que justificar en la revisión. Con
// `ImageSource.camera` de `image_picker` el sistema abre SU cámara con
// `ACTION_IMAGE_CAPTURE` y devuelve el archivo: cero permisos nuevos. El
// APK de esta app tiene exactamente dos permisos y se cuida a propósito.
//
// LA TRAMPA, Y ESTÁ DOCUMENTADA EN developer.android.com: si una app
// DECLARA `CAMERA` y el usuario no lo ha CONCEDIDO, `ACTION_IMAGE_CAPTURE`
// lanza `SecurityException`. O sea que declarar el permiso "por si acaso"
// no es neutro: rompe esta función. Comprobado sobre el manifiesto
// fusionado; el procedimiento está en el comentario de
// `android/app/src/main/AndroidManifest.xml`.
//
// LA GALERÍA DEVUELVE IMÁGENES, NO PDF. `image_picker` no tiene ninguna
// API que devuelva un PDF: ni `pickImage` ni `pickMedia`. Por eso la
// opción de la hoja de origen se llama "Elegir una imagen de la galería" y
// NO "una imagen o un PDF": un rótulo que ofrezca algo que el selector no
// puede dar es un píxel que afirma lo que el código no hace. El camino del
// PDF existe y es el de compartir, que sí lo entrega.
// ═══════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/receipt_document.dart';
import '../../domain/repositories/receipt_scan_repository.dart';

class ReceiptPickerDatasource {
  final ImagePicker _picker;

  ReceiptPickerDatasource({final ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  /// Abre la cámara del sistema. `null` si el usuario canceló.
  Future<ReceiptDocument?> tomarFoto() => _elegir(
        ImageSource.camera,
        ReceiptScanSource.camara,
        'No pude abrir la cámara del teléfono.',
        'Puedes elegir una foto de la galería o escribir la ficha a mano.',
      );

  /// Abre el selector de imágenes del sistema. `null` si canceló.
  Future<ReceiptDocument?> elegirImagen() => _elegir(
        ImageSource.gallery,
        ReceiptScanSource.galeria,
        'No pude abrir la galería del teléfono.',
        'Puedes tomar una foto o escribir la ficha a mano.',
      );

  Future<ReceiptDocument?> _elegir(
    final ImageSource origen,
    final ReceiptScanSource fuente,
    final String mensaje,
    final String pista,
  ) async {
    final XFile? archivo;
    try {
      // SIN `maxWidth`/`maxHeight`/`imageQuality`. Recomprimir la foto le
      // quita resolución al texto, que es justo lo que ML Kit necesita: una
      // boleta térmica con el cuerpo a 7 puntos deja de leerse. El tope de
      // tamaño se aplica después, sobre el archivo, en `MlkitTextReader`.
      archivo = await _picker.pickImage(source: origen);
    } catch (e) {
      // CANCELAR NO LLEGA AQUÍ: `image_picker` devuelve `null`. Lo que
      // llega aquí es un permiso denegado de verdad, un `SecurityException`
      // por un permiso declarado y no concedido, o que no haya ninguna app
      // de cámara. En los tres casos la app sigue funcionando y lo dice.
      debugPrint('ReceiptPickerDatasource(${origen.name}) falló: $e');
      throw ReceiptScanException('origen-no-disponible', mensaje, hint: pista);
    }

    if (archivo == null) return null;

    return ReceiptDocument(
      path: archivo.path,
      // `XFile.mimeType` suele venir nulo en Android, así que se deduce de
      // la extensión antes de darlo por desconocido.
      mimeType: archivo.mimeType ?? ReceiptDocument.mimeDeLaExtension(
        archivo.path,
      ),
      source: fuente,
    );
  }
}
