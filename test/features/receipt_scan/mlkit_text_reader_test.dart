// Los caminos del lector que NO necesitan el plugin nativo.
//
// LO QUE ESTE ARCHIVO PROTEGE DE VERDAD es la promesa de privacidad: la
// política publicada en la landing afirma que la imagen no se guarda, así
// que hay un test por cada forma de salir de `leer` que comprueba que el
// archivo DEJÓ DE EXISTIR. Si ese borrado se rompe, lo que miente no es un
// formulario: es un documento legal.
//
// `processImage` sí necesita ML Kit, así que el camino de éxito se prueba
// en el emulador, con una boleta de verdad, y queda en docs/capturas/.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/receipt_scan/data/datasources/mlkit_text_reader.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_document.dart';
import 'package:pagate_ia/features/receipt_scan/domain/repositories/receipt_scan_repository.dart';

void main() {
  late Directory temporal;

  setUp(() {
    temporal = Directory.systemTemp.createTempSync('pagate_lector_test');
  });

  tearDown(() {
    // En Windows el antivirus puede tener todavía abierto el archivo de
    // 10 MB cuando el test acaba, y `deleteSync` falla con errno 32. Que la
    // limpieza del directorio temporal no haga rojo un test que ya pasó.
    try {
      if (temporal.existsSync()) temporal.deleteSync(recursive: true);
    } on FileSystemException catch (_) {
      // Lo borra el sistema con la sesión.
    }
  });

  File archivo(final String nombre, {final int bytes = 32}) {
    final f = File('${temporal.path}/$nombre')
      ..writeAsBytesSync(List<int>.filled(bytes, 0));
    return f;
  }

  ReceiptDocument doc(final File f, {final String? mime}) => ReceiptDocument(
        path: f.path,
        mimeType: mime ?? ReceiptDocument.mimeDeLaExtension(f.path),
        source: ReceiptScanSource.compartido,
      );

  group('mimeDeLaExtension', () {
    test('deduce el tipo cuando el sistema no lo dice', () {
      // `receive_sharing_intent` deja `mimeType` nulo con frecuencia en
      // Android: sin esto, una boleta en PDF compartida desde Archivos se
      // descartaría por "tipo no soportado" siendo perfectamente legible.
      expect(ReceiptDocument.mimeDeLaExtension('/a/b.PDF'), 'application/pdf');
      expect(ReceiptDocument.mimeDeLaExtension('/a/b.jpg'), 'image/jpeg');
      expect(ReceiptDocument.mimeDeLaExtension('/a/b.jpeg'), 'image/jpeg');
      expect(ReceiptDocument.mimeDeLaExtension('/a/b.png'), 'image/png');
      expect(ReceiptDocument.mimeDeLaExtension('/a/b.heic'), 'image/heic');
      expect(
        ReceiptDocument.mimeDeLaExtension('/a/b.mp3'),
        'application/octet-stream',
      );
    });

    test('esLegible solo acepta imagen y PDF', () {
      expect(doc(archivo('x.jpg')).esLegible, isTrue);
      expect(doc(archivo('x.pdf')).esLegible, isTrue);
      expect(doc(archivo('x.mp3')).esLegible, isFalse);
    });
  });

  group('errores de lectura', () {
    test('un archivo que ya no está lo dice sin reventar', () async {
      final lector = MlkitTextReader(directorioTemporal: () async => temporal);
      final doc = ReceiptDocument(
        path: '${temporal.path}/no_existe.jpg',
        mimeType: 'image/jpeg',
        source: ReceiptScanSource.camara,
      );

      await expectLater(
        lector.leer(doc),
        throwsA(
          isA<ReceiptScanException>().having(
            (final e) => e.code,
            'code',
            'archivo-ausente',
          ),
        ),
      );
    });

    test('un tipo que no sabe leer lo dice, Y BORRA EL ARCHIVO', () async {
      final lector = MlkitTextReader(directorioTemporal: () async => temporal);
      final sonido = archivo('cancion.mp3');

      await expectLater(
        lector.leer(doc(sonido)),
        throwsA(
          isA<ReceiptScanException>().having(
            (final e) => e.code,
            'code',
            'tipo-no-soportado',
          ),
        ),
      );
      expect(
        sonido.existsSync(),
        isFalse,
        reason: 'el `finally` tiene que borrar también cuando falla',
      );
    });

    test('por encima de 10 MB lo dice con el peso, Y BORRA EL ARCHIVO',
        () async {
      final lector = MlkitTextReader(directorioTemporal: () async => temporal);
      final enorme = archivo(
        'enorme.jpg',
        bytes: ReceiptDocument.maxBytes + 1024,
      );

      await expectLater(
        lector.leer(doc(enorme)),
        throwsA(
          isA<ReceiptScanException>()
              .having((final e) => e.code, 'code', 'demasiado-grande')
              // El mensaje dice el peso real y el tope: "pesa X y el tope
              // son 10 MB" se puede actuar, "archivo demasiado grande" no.
              .having(
                (final e) => e.message,
                'message',
                contains('10 MB'),
              ),
        ),
      );
      expect(enorme.existsSync(), isFalse);
    });
  });

  group('borrar', () {
    test('borra el archivo', () async {
      final boleta = archivo('boleta.jpg');
      await doc(boleta).borrar();
      expect(boleta.existsSync(), isFalse);
    });

    test('sobre un archivo que ya no está no lanza', () async {
      final doc = ReceiptDocument(
        path: '${temporal.path}/fantasma.jpg',
        mimeType: 'image/jpeg',
        source: ReceiptScanSource.camara,
      );
      // Si lanzara, una excepción al borrar taparía el resultado de la
      // lectura desde el `finally`.
      await expectLater(doc.borrar(), completes);
    });
  });
}
