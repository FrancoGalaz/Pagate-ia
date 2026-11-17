// PROPÓSITO
// ---------
// Revisión prelanzamiento 5.2. El cliente cortaba la espera del asistente a
// los 45 s y el servidor tiene hasta 60 s: con OpenRouter lento, la persona
// veía «El asistente no responde» mientras la función terminaba, guardaba la
// respuesta y gastaba el mensaje. Al reenviar gastaba otro y la pregunta
// quedaba dos veces en el historial.
//
// El plazo del cliente tiene que pasar al del servidor, y eso vale tanto para
// el `.timeout` de Dart como para el del plugin (`HttpsCallableOptions`), que
// por defecto corta a los 60 s.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/ai_service.dart';

/// `timeoutSeconds` del callable `chat`, leído de su código fuente para que
/// los dos números no se separen sin que falle un test.
Duration _plazoDelServidor() {
  final codigo = File('functions/src/chat.ts').readAsStringSync();
  final m = RegExp(r'timeoutSeconds:\s*(\d+)').firstMatch(codigo);
  expect(m, isNotNull, reason: 'chat.ts debería declarar timeoutSeconds');
  return Duration(seconds: int.parse(m!.group(1)!));
}

void main() {
  test('el cliente espera más que el servidor', () {
    expect(AiService.timeout, greaterThan(_plazoDelServidor()));
  });

  test('el plugin también: su plazo por defecto (60 s) no corta antes', () {
    expect(AiService.opciones.timeout, AiService.timeout);
  });
}
