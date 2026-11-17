// LA CUARTA ENTRADA DEL LECTOR: UN ARCHIVO QUE YA ESTÁ EN EL TELÉFONO.
//
// Sin plugin nativo: lo que se inyecta es la llamada al selector del
// sistema (`SelectorDeDocumento`), así que se puede escribir qué eligió el
// usuario y comprobar qué documento sale hacia la tubería de lectura.
//
// LO QUE IMPORTA AQUÍ son las tres salidas que NO son la buena, porque son
// las que se confunden si nadie las fija: cancelar no es un error, un
// archivo de la nube sin descargar no es "una foto borrosa", y un fallo del
// canal nativo tiene que llegar con un mensaje que una persona entienda.

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/receipt_scan/data/datasources/receipt_picker_datasource.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_document.dart';
import 'package:pagate_ia/features/receipt_scan/domain/repositories/receipt_scan_repository.dart';

ReceiptPickerDatasource _conSelector(
  final Future<ArchivoElegido?> Function() selector,
) =>
    ReceiptPickerDatasource(selectorDeDocumento: selector);

void main() {
  test('un PDF de Descargas sale como documento legible', () async {
    final datasource = _conSelector(
      () async => const ArchivoElegido('/cache/boleta_octubre.pdf'),
    );

    final doc = await datasource.elegirDocumento();

    expect(doc, isNotNull);
    expect(doc!.path, '/cache/boleta_octubre.pdf');
    expect(doc.mimeType, 'application/pdf');
    expect(doc.esPdf, isTrue);
    expect(doc.esLegible, isTrue);
    expect(
      doc.source,
      ReceiptScanSource.archivo,
      reason: 'el origen se registra: no es una foto ni algo compartido',
    );
  });

  test('una imagen guardada también entra, con su MIME', () async {
    for (final caso in const [
      ('/cache/boleta.jpg', 'image/jpeg'),
      ('/cache/boleta.jpeg', 'image/jpeg'),
      ('/cache/boleta.png', 'image/png'),
      ('/cache/boleta.webp', 'image/webp'),
    ]) {
      final doc = await _conSelector(
        () async => ArchivoElegido(caso.$1),
      ).elegirDocumento();

      expect(doc!.mimeType, caso.$2, reason: caso.$1);
      expect(doc.esImagen, isTrue);
    }
  });

  test('el MIME se deduce de la extensión en MAYÚSCULAS igual', () async {
    // El selector de Android devuelve el nombre tal como está en el
    // sistema de archivos, y `BOLETA.PDF` existe.
    final doc = await _conSelector(
      () async => const ArchivoElegido('/cache/BOLETA.PDF'),
    ).elegirDocumento();

    expect(doc!.esPdf, isTrue);
  });

  test('cancelar NO es un error: devuelve null y no se dice nada', () async {
    final doc = await _conSelector(() async => null).elegirDocumento();

    expect(doc, isNull);
  });

  test('un archivo de la nube sin descargar lo dice, y dice qué hacer',
      () async {
    // `PlatformFile.path` es nulo cuando el proveedor de Android no
    // materializa el archivo. Dejarlo pasar daba "no pude leer nada de esa
    // imagen", que es falso: la boleta está bien, lo que no está es el
    // archivo.
    final datasource = _conSelector(() async => const ArchivoElegido(null));

    await expectLater(
      datasource.elegirDocumento(),
      throwsA(
        isA<ReceiptScanException>()
            .having((final e) => e.code, 'code', 'archivo-sin-ruta')
            .having(
              (final e) => e.message,
              'message',
              contains('no está guardado en el teléfono'),
            )
            .having((final e) => e.hint, 'hint', isNotNull),
      ),
    );
  });

  test('una ruta vacía se trata igual que una ausente', () async {
    await expectLater(
      _conSelector(() async => const ArchivoElegido('')).elegirDocumento(),
      throwsA(
        isA<ReceiptScanException>()
            .having((final e) => e.code, 'code', 'archivo-sin-ruta'),
      ),
    );
  });

  test('si el selector del sistema falla, el mensaje es para una persona',
      () async {
    final datasource = _conSelector(
      () async => throw StateError('no hay actividad que atienda el intento'),
    );

    await expectLater(
      datasource.elegirDocumento(),
      throwsA(
        isA<ReceiptScanException>()
            .having((final e) => e.code, 'code', 'origen-no-disponible')
            .having(
              (final e) => e.message,
              'message',
              'No pude abrir los archivos del teléfono.',
            )
            .having(
              (final e) => e.hint,
              'hint',
              contains('escribir la ficha a mano'),
            ),
      ),
    );
  });

  group('el filtro de extensiones', () {
    test('son exactamente las que el lector sabe leer', () {
      expect(kExtensionesDeBoleta, ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
    });

    test('todas producen un documento que el lector acepta', () {
      // Si alguien añade una extensión al filtro que `ReceiptDocument` no
      // reconoce, el selector la ofrecería y la lectura la rechazaría
      // después: ofrecer lo que no se puede cumplir.
      for (final extension in kExtensionesDeBoleta) {
        final doc = ReceiptDocument(
          path: '/cache/boleta.$extension',
          mimeType: ReceiptDocument.mimeDeLaExtension('/cache/b.$extension'),
          source: ReceiptScanSource.archivo,
        );
        expect(doc.esLegible, isTrue, reason: extension);
      }
    });
  });
}
