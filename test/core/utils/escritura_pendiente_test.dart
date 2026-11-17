// PROPÓSITO
// ---------
// Revisión prelanzamiento 5.1, último caso: algo guardado sin conexión que el
// servidor rechaza al sincronizar. La pantalla que lo guardó ya avisó
// «Guardado en el teléfono» y quizá ya se cerró; si nadie avisa, el usuario
// cree que quedó guardado y no lo está.
//
// Aquí se comprueba que el rechazo tardío llega a quien avisa
// (`RechazoAlSincronizar.avisar`, que registra `AppShell`) con un texto que
// dice QUÉ no se guardó. Que `AppShell` lo pinte está en `app_shell_test`.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/utils/escritura_pendiente.dart';

FirebaseException _rechazo() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

void main() {
  late List<String> avisos;

  setUp(() {
    avisos = [];
    RechazoAlSincronizar.avisar = avisos.add;
  });

  tearDown(() => RechazoAlSincronizar.avisar = null);

  testWidgets('si el servidor rechaza después del plazo, se avisa qué no se '
      'guardó', (final tester) async {
    final escritura = Completer<void>();
    bool? confirmada;
    unawaited(
      confirmadaATiempo(
        escritura.future,
        siSeRechaza: 'No se pudo guardar el movimiento «Venta en feria».',
      ).then((final r) => confirmada = r),
    );
    await tester.pump(kEsperaConfirmacion + const Duration(seconds: 1));
    expect(confirmada, isFalse);
    expect(avisos, isEmpty, reason: 'todavía no hay rechazo');

    escritura.completeError(_rechazo());
    await tester.pump();

    expect(avisos, ['No se pudo guardar el movimiento «Venta en feria».']);
  });

  testWidgets('si rechaza dentro del plazo, el error va a la pantalla y no '
      'hay aviso aparte', (final tester) async {
    final escritura = Completer<void>();
    Object? error;
    unawaited(
      confirmadaATiempo(escritura.future, siSeRechaza: 'No se guardó')
          .catchError((final Object e) {
        error = e;
        return true;
      }),
    );
    escritura.completeError(_rechazo());
    await tester.pump();

    expect(error, isA<FirebaseException>());
    expect(avisos, isEmpty);
  });

  testWidgets('si el servidor la confirma tarde, no hay aviso', (
    final tester,
  ) async {
    final escritura = Completer<void>();
    unawaited(confirmadaATiempo(escritura.future, siSeRechaza: 'No se guardó'));
    await tester.pump(kEsperaConfirmacion + const Duration(seconds: 1));
    escritura.complete();
    await tester.pump();

    expect(avisos, isEmpty);
  });
}
