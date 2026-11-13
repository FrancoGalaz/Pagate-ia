// ═══════════════════════════════════════════════════════════════════════
// UNA BOLETA COMPARTIDA A PÁGATE DESDE OTRA APP
// ═══════════════════════════════════════════════════════════════════════
// Es la tercera entrada y la única que no la inicia el usuario dentro de
// la app: llega de WhatsApp, del correo o de Archivos. Hay dos momentos
// distintos y los dos hacen falta:
//
//   · `getInitialMedia()` — la app estaba CERRADA y el sistema la abrió
//     con el archivo. Se consulta una vez al montar.
//   · `getMediaStream()`  — la app ya estaba abierta. Su propia
//     documentación avisa de que este stream NO emite la entrega inicial,
//     así que con solo uno de los dos la mitad de los casos se pierde.
//
// `reset()` SE LLAMA SIEMPRE tras procesar. Sin él, `getInitialMedia()`
// devuelve la misma entrega cada vez que se consulta, así que la pantalla
// de lectura reaparecería sola al volver a Inventario.
//
// PRIVACIDAD: la documentación del plugin dice «all files are copied to a
// temp cache folder». Ese archivo copiado es nuestro y hay que borrarlo:
// lo hace `ReceiptDocument.borrar()` desde el `finally` de
// `MlkitTextReader`, que cubre también el camino de error. Si no se
// borrara, lo que mentiría es la política de privacidad publicada.
// ═══════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../domain/entities/receipt_document.dart';

/// Lo que llegó compartido, ya filtrado.
class SharedReceipt {
  /// El primero de los archivos que la app sabe leer, o `null`.
  final ReceiptDocument? documento;

  /// Aviso que la interfaz tiene que decir, o `null`.
  ///
  /// Se separa del documento porque las dos cosas pueden darse a la vez:
  /// llegan tres archivos, se lee el primero Y se avisa de que los otros
  /// dos no. Callárselo haría pensar que se leyeron los tres.
  final String? aviso;

  const SharedReceipt({this.documento, this.aviso});

  bool get hayAlgo => documento != null || aviso != null;
}

class ReceiptShareDatasource {
  final ReceiveSharingIntent _intents;

  ReceiptShareDatasource({final ReceiveSharingIntent? intents})
      : _intents = intents ?? ReceiveSharingIntent.instance;

  /// Lo que abrió la app, si la abrió un archivo compartido.
  Future<SharedReceipt> inicial() async {
    try {
      return _traducir(await _intents.getInitialMedia());
    } catch (e) {
      debugPrint('ReceiptShareDatasource.inicial falló: $e');
      return const SharedReceipt();
    }
  }

  /// Entregas que llegan con la app ya abierta.
  Stream<SharedReceipt> entregas() => _intents
      .getMediaStream()
      .map(_traducir)
      .handleError((final Object e) {
        debugPrint('ReceiptShareDatasource.entregas falló: $e');
      });

  /// Marca la entrega como consumida.
  Future<void> consumir() async {
    try {
      await _intents.reset();
    } catch (e) {
      debugPrint('ReceiptShareDatasource.consumir falló: $e');
    }
  }

  SharedReceipt _traducir(final List<SharedMediaFile> archivos) {
    if (archivos.isEmpty) return const SharedReceipt();

    final legibles = <ReceiptDocument>[];
    for (final archivo in archivos) {
      final mime = archivo.mimeType?.trim();
      final doc = ReceiptDocument(
        path: archivo.path,
        mimeType: mime == null || mime.isEmpty
            ? ReceiptDocument.mimeDeLaExtension(archivo.path)
            : mime,
        source: ReceiptScanSource.compartido,
      );
      if (doc.esLegible) legibles.add(doc);
    }

    if (legibles.isEmpty) {
      return SharedReceipt(
        aviso: archivos.length == 1
            ? 'Lo que compartiste no es una imagen ni un PDF, así que no '
                'puedo leerlo.'
            : 'Ninguno de los ${archivos.length} archivos es una imagen o '
                'un PDF, así que no puedo leerlos.',
      );
    }

    return SharedReceipt(
      documento: legibles.first,
      aviso: archivos.length > 1
          ? 'Llegaron ${archivos.length} archivos. Leí el primero.'
          : null,
    );
  }
}
