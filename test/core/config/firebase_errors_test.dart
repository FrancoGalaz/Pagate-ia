// describeFirebaseError: códigos conocidos en español; un código desconocido
// da un mensaje genérico y el texto original de Firebase solo en debug.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/config/firebase_errors.dart';

FirebaseException _error(final String code) => FirebaseException(
  plugin: 'firebase_auth',
  code: code,
  message: 'An internal error has occurred. [ RAW_SERVER_TEXT ]',
);

void main() {
  late List<String?> registro;
  late DebugPrintCallback original;

  setUp(() {
    registro = [];
    original = debugPrint;
    debugPrint = (final message, {final wrapWidth}) => registro.add(message);
  });
  tearDown(() => debugPrint = original);

  test('un código conocido sigue en español', () {
    expect(
      describeFirebaseError(_error('invalid-email'), mostrarDetalle: false),
      'El correo no tiene un formato válido.',
    );
  });

  test('un código desconocido en release da un mensaje genérico', () {
    final texto = describeFirebaseError(
      _error('internal-error'),
      mostrarDetalle: false,
    );

    expect(texto, 'No pudimos completar la operación. Inténtalo de nuevo.');
    expect(texto, isNot(contains('RAW_SERVER_TEXT')));
    expect(registro.single, contains('internal-error'));
    expect(registro.single, contains('RAW_SERVER_TEXT'));
  });

  test('en debug muestra el texto original', () {
    expect(
      describeFirebaseError(_error('internal-error'), mostrarDetalle: true),
      contains('RAW_SERVER_TEXT'),
    );
  });
}
