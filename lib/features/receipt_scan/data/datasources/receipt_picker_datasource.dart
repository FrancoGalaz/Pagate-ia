// ═══════════════════════════════════════════════════════════════════════
// LA CÁMARA, LA GALERÍA Y EL SELECTOR DE DOCUMENTOS: LOS DEL SISTEMA
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
// puede dar es un píxel que afirma lo que el código no hace.
//
// ─── Y POR ESO EXISTE LA CUARTA ENTRADA ────────────────────────────────
//
// [elegirDocumento] es la que pidió el dueño: un archivo que YA ESTÁ
// GUARDADO en el teléfono, típicamente un PDF en Descargas. Ni la cámara
// ni la galería pueden darlo, y compartir desde otra app obliga a salir de
// Págate, abrir Archivos y volver. Alimenta exactamente la misma tubería:
// un [ReceiptDocument] y de ahí el camino es único.
//
// TAMPOCO AÑADE NI UN PERMISO, y es el motivo de usar este camino. En
// Android `file_picker` con `FileType.custom` lanza
// `Intent.ACTION_OPEN_DOCUMENT`, que es el MARCO DE ACCESO AL
// ALMACENAMIENTO: el sistema abre su selector, el usuario elige UN archivo
// y la app recibe acceso solo a ese `content://`. `READ_EXTERNAL_STORAGE`
// daría acceso a TODO el almacenamiento, saldría en la ficha de Play y
// habría que justificarlo. Verificado leyendo el manifiesto de
// `android_file_picker-2.0.1` (solo aporta un bloque `<queries>`, ningún
// `uses-permission`) y comprobado sobre el APK de release con
// `build-tools/36.1.0/aapt2.exe dump permissions`.
// ═══════════════════════════════════════════════════════════════════════

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/receipt_document.dart';
import '../../domain/repositories/receipt_scan_repository.dart';

/// Extensiones que el selector de documentos ofrece.
///
/// Son exactamente las que [MlkitTextReader] sabe leer, y el filtro no es
/// cosmético: sin él el selector deja elegir un `.docx` o un `.zip` y la app
/// tendría que decir después que no sabe leerlo. Ofrecer solo lo que se
/// puede cumplir es el principio 7 de docs/DISENO-v2.md.
///
/// `heic` NO está, aunque el lector lo acepte por MIME: en Android el
/// selector del sistema ya entrega las fotos como JPEG, y poner una
/// extensión de iOS en el filtro de Android solo añade una opción que no
/// aparece nunca.
const List<String> kExtensionesDeBoleta = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

/// Lo que devolvió el selector del sistema.
///
/// Existe para que [path] pueda ser nulo SIN que eso se confunda con
/// "el usuario canceló": son dos casos distintos y se dicen de forma
/// distinta. Cancelar devuelve `null` en vez de este objeto.
@immutable
class ArchivoElegido {
  /// Ruta en el disco local, o `null` si el archivo no está descargado (un
  /// documento de la nube que el proveedor de Android no materializa).
  final String? path;

  const ArchivoElegido(this.path);
}

/// Cómo se abre el selector de documentos. Inyectable para los tests, que
/// no tienen plugin nativo.
///
/// Hace falta un alias porque `FilePicker` es `abstract final` y sus
/// métodos son ESTÁTICOS: no se puede pasar otra instancia como con
/// `ImagePicker`. Lo que se inyecta es la llamada, traducida a
/// [ArchivoElegido] para que los tests no tengan que construir un
/// `PlatformFile` del plugin.
typedef SelectorDeDocumento = Future<ArchivoElegido?> Function();

Future<ArchivoElegido?> _selectorDelSistema() async {
  final archivo = await FilePicker.pickFile(
    dialogTitle: 'Elige la boleta',
    // `custom` + extensiones es lo que hace que el plugin use
    // `ACTION_OPEN_DOCUMENT` en vez de `ACTION_GET_CONTENT` con un
    // comodín de medios: el selector de documentos, no el de fotos.
    type: FileType.custom,
    allowedExtensions: kExtensionesDeBoleta,
  );
  return archivo == null ? null : ArchivoElegido(archivo.path);
}

class ReceiptPickerDatasource {
  final ImagePicker _picker;
  final SelectorDeDocumento _selectorDeDocumento;

  ReceiptPickerDatasource({
    final ImagePicker? picker,
    final SelectorDeDocumento? selectorDeDocumento,
  })  : _picker = picker ?? ImagePicker(),
        _selectorDeDocumento = selectorDeDocumento ?? _selectorDelSistema;

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

  /// Abre el selector de documentos del sistema. `null` si canceló.
  ///
  /// Devuelve un PDF o una imagen que ya estaba guardada en el teléfono.
  Future<ReceiptDocument?> elegirDocumento() async {
    final ArchivoElegido? archivo;
    try {
      archivo = await _selectorDeDocumento();
    } catch (e) {
      // CANCELAR NO LLEGA AQUÍ: `file_picker` devuelve `null` (o una lista
      // vacía) cuando el usuario cierra el selector. Lo que llega aquí es
      // que no haya ninguna app que atienda `ACTION_OPEN_DOCUMENT`, o un
      // fallo del canal nativo.
      debugPrint('ReceiptPickerDatasource.elegirDocumento falló: $e');
      throw const ReceiptScanException(
        'origen-no-disponible',
        'No pude abrir los archivos del teléfono.',
        hint: 'Puedes tomar una foto de la boleta o escribir la ficha a mano.',
      );
    }

    if (archivo == null) return null;

    // `path` es nulo cuando el archivo elegido no está en el disco local
    // (un documento de la nube que el proveedor no descarga). NO se puede
    // leer, y decirlo es mejor que mostrar "no pude leer nada de esa
    // imagen", que haría pensar que la boleta salió borrosa.
    final ruta = archivo.path;
    if (ruta == null || ruta.isEmpty) {
      throw const ReceiptScanException(
        'archivo-sin-ruta',
        'Ese archivo no está guardado en el teléfono, así que no puedo '
            'abrirlo.',
        hint: 'Descárgalo primero, o compártelo desde la app donde lo '
            'tienes.',
      );
    }

    return ReceiptDocument(
      path: ruta,
      // Se deduce de la extensión y no se pregunta al plugin: su
      // `PlatformFile` no expone el MIME, y con el filtro de extensiones
      // puesto la extensión es exactamente lo que el usuario eligió.
      mimeType: ReceiptDocument.mimeDeLaExtension(ruta),
      source: ReceiptScanSource.archivo,
    );
  }

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
