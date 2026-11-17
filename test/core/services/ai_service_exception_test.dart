// PROPÓSITO: fijar qué lee el usuario cuando el asistente falla.
//
// El defecto que cierra: `AiService` descartaba `e.message` del callable y
// mostraba siempre el mismo texto, "Alcanzaste el límite diario de mensajes.
// Vuelve mañana o pasa a Pro". Con la cuota del backend ese texto era falso
// tres veces:
//   1. la cuota del plan gratuito es DE POR VIDA (`FREE_LIFETIME_QUOTA`), no
//      diaria, así que no se renueva mañana;
//   2. el mismo código `resource-exhausted` lo lanza también el tope global
//      del día del dueño, que no es un límite del usuario;
//   3. no existe ningún plan Pro que se pueda comprar dentro de la app.
//
// La regla que se prueba aquí: manda el mensaje del servidor, y el respaldo
// local solo entra cuando no llega un texto escrito para una persona.

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/ai_service.dart';

void main() {
  group('AiServiceException.from', () {
    test('usa el mensaje del servidor tal cual cuando viene escrito', () {
      // El texto exacto que lanza hoy functions/src/quota.ts para el plan
      // gratuito. El cliente no conoce ni el número ni el plan: solo lo
      // reenvía.
      const serverText =
          'Usaste los 25 mensajes incluidos en el plan gratuito. '
          'Cambia a Pro para seguir conversando con el asistente.';

      final error = AiServiceException.from('resource-exhausted', serverText);

      expect(error.message, serverText);
      expect(error.fromServer, isTrue);
      expect(error.code, 'resource-exhausted');
    });

    test('el respaldo de cuota no promete que se renueve ni vender un plan', () {
      final error = AiServiceException.from('resource-exhausted', null);

      expect(error.fromServer, isFalse);
      final texto = error.message.toLowerCase();
      expect(texto, isNot(contains('diario')));
      expect(texto, isNot(contains('mañana')));
      expect(texto, isNot(contains('pro')));
    });

    test('descarta los marcadores en mayúsculas que rellena el SDK', () {
      // Cuando el fallo no lo lanza el backend sino la infraestructura, el
      // SDK pone el código en mayúsculas en `message`. Enseñárselo al usuario
      // sería peor que el texto fijo que había antes.
      for (final marcador in ['INTERNAL', 'UNAVAILABLE', 'DEADLINE_EXCEEDED']) {
        final error = AiServiceException.from('internal', marcador);
        expect(error.fromServer, isFalse, reason: marcador);
        expect(error.message, isNot(contains(marcador)));
      }
    });

    test('descarta un mensaje vacío o demasiado corto', () {
      for (final vacio in [null, '', '   ', 'error']) {
        final error = AiServiceException.from('unknown', vacio);
        expect(error.fromServer, isFalse, reason: '"$vacio"');
      }
    });

    test('cada código sin mensaje del servidor tiene su propio respaldo', () {
      String texto(final String code) =>
          AiServiceException.from(code, null).message;

      expect(texto('unauthenticated'), contains('Inicia sesión'));
      expect(texto('unavailable'), texto('deadline-exceeded'));
      expect(texto('loquesea'), isNotEmpty);
      // Ningún respaldo puede quedarse en blanco: el banner de error del chat
      // muestra este texto y un banner vacío es peor que no mostrarlo.
      for (final code in [
        'resource-exhausted',
        'unauthenticated',
        'unavailable',
        'deadline-exceeded',
        'internal',
        'unknown',
      ]) {
        expect(texto(code).trim(), isNotEmpty, reason: code);
      }
    });
  });
}
