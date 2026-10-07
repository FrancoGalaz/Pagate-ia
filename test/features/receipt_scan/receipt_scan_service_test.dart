// El cliente del callable: qué mensaje lee el usuario y qué se descarta.
//
// NO SE LEVANTA FIREBASE. Lo que se prueba es la traducción de errores y la
// validación de la respuesta, que son las dos piezas donde el cliente
// decide por su cuenta y donde puede mentir.

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/receipt_scan_service.dart';

void main() {
  group('el mensaje del servidor manda', () {
    test('un texto redactado por el backend se muestra tal cual', () {
      final e = ReceiptScanServiceException.from(
        'resource-exhausted',
        'Usaste las 40 lecturas de boleta de tu plan.',
      );

      expect(e.message, 'Usaste las 40 lecturas de boleta de tu plan.');
      expect(e.fromServer, isTrue);
    });

    test('un marcador del SDK no se le enseña a nadie', () {
      // El SDK rellena `message` con el código en mayúsculas cuando el
      // fallo lo genera la infraestructura: 'INTERNAL' no significa nada
      // fuera de una consola.
      final e = ReceiptScanServiceException.from('internal', 'INTERNAL');

      expect(e.message, 'No pude ordenar la boleta.');
      expect(e.fromServer, isFalse);
    });

    test('el respaldo de cuota NO promete que se renueve mañana', () {
      // La cuota del plan gratuito es DE POR VIDA, el mismo código lo lanza
      // el tope global del dueño, y no hay plan que comprar dentro de la
      // app: cualquier "vuelve mañana" sería falso tres veces.
      final e = ReceiptScanServiceException.from('resource-exhausted', null);

      expect(e.message, isNot(contains('mañana')));
      expect(e.message, isNot(contains('Pro')));
      expect(e.esCuota, isTrue);
    });

    test('un fallo del proveedor no se confunde con cuota agotada', () {
      expect(
        ReceiptScanServiceException.from('unavailable', null).esCuota,
        isFalse,
      );
    });

    test('cada código tiene su propio texto, sin genéricos', () {
      final textos = {
        for (final codigo in [
          'resource-exhausted',
          'unauthenticated',
          'invalid-argument',
          'unavailable',
          'internal',
        ])
          codigo: ReceiptScanServiceException.from(codigo, null).message,
      };

      expect(textos.values.toSet(), hasLength(5));
      for (final texto in textos.values) {
        expect(texto, isNot(isEmpty));
        expect(texto.trim(), endsWith('.'));
      }
    });
  });

  group('tope de texto', () {
    test('el tope del backend está declarado en el cliente', () {
      // Se recorta aquí para no gastar una llamada que el servidor va a
      // rechazar con `invalid-argument`.
      expect(ReceiptScanService.maxTextChars, 8000);
    });
  });
}
