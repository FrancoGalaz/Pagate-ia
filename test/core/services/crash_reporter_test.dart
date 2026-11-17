// PROPÓSITO
// ---------
// Durante la prueba cerrada hay que saber qué falla en los teléfonos de los
// probadores, y la política de privacidad promete que eso se hace sin datos
// personales. Aquí se comprueba las dos cosas:
//
//   1. Llegan al destino los tres tipos de fallo: errores de Flutter, errores
//      sin capturar (los que cerrarían la app) y el rechazo de una escritura
//      que se guardó sin conexión.
//   2. Lo que llega es el TIPO del error y la traza del código, nunca el
//      mensaje de la excepción: un mensaje puede citar lo que el usuario
//      escribió, su correo o la ruta `users/{uid}/...`.
//   3. No hay Analytics ni identificador de usuario en ninguna parte.
//
// El destino real es Crashlytics (`CrashlyticsSink`); aquí va un doble.

import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/crash_reporter.dart';
import 'package:pagate_ia/core/utils/escritura_pendiente.dart';

class _Reporte {
  _Reporte(this.tipo, this.traza, this.motivo, this.fatal);
  final String tipo;
  final StackTrace? traza;
  final String motivo;
  final bool fatal;

  /// Todo el texto que saldría del teléfono.
  String get texto => '$tipo | $motivo';
}

class _DestinoFalso implements CrashSink {
  final List<_Reporte> reportes = [];

  @override
  void record(
    final String tipo,
    final StackTrace? traza, {
    required final String motivo,
    required final bool fatal,
  }) =>
      reportes.add(_Reporte(tipo, traza, motivo, fatal));
}

const _uid = 'kT9xQ2mUidDeUnaCuentaReal0001';
const _correo = 'artesana@example.com';

void main() {
  late _DestinoFalso destino;

  setUp(() {
    destino = _DestinoFalso();
    CrashReporter.destino = destino;
  });

  tearDown(() => CrashReporter.destino = null);

  group('qué llega', () {
    test('un error de Flutter llega como fatal', () {
      final previo = FlutterError.onError;
      final previoPlataforma = PlatformDispatcher.instance.onError;
      CrashReporter.instalar(destino);
      final manejador = FlutterError.onError!;
      FlutterError.onError = previo;
      PlatformDispatcher.instance.onError = previoPlataforma;

      manejador(
        FlutterErrorDetails(
          exception: StateError('sin estado'),
          stack: StackTrace.current,
          library: 'widgets library',
        ),
      );

      expect(destino.reportes, hasLength(1));
      expect(destino.reportes.single.tipo, 'StateError');
      expect(destino.reportes.single.fatal, isTrue);
      expect(destino.reportes.single.traza, isNotNull);
    });

    test('un error sin capturar (el que cerraría la app) llega como fatal', () {
      final previo = FlutterError.onError;
      final previoPlataforma = PlatformDispatcher.instance.onError;
      CrashReporter.instalar(destino);
      final manejador = PlatformDispatcher.instance.onError!;
      FlutterError.onError = previo;
      PlatformDispatcher.instance.onError = previoPlataforma;

      final atendido = manejador(const FormatException('x'), StackTrace.current);

      expect(atendido, isTrue);
      expect(destino.reportes.single.tipo, 'FormatException');
      expect(destino.reportes.single.fatal, isTrue);
    });

    testWidgets('el rechazo de una escritura al sincronizar llega, no fatal', (
      final tester,
    ) async {
      // Sin conexión la escritura no confirma; al volver la red, las reglas
      // la rechazan. Ya no hay pantalla a la que avisar.
      final escritura = Completer<void>();
      bool? confirmada;
      unawaited(
        confirmadaATiempo(escritura.future).then((final r) => confirmada = r),
      );
      await tester.pump(kEsperaConfirmacion + const Duration(seconds: 1));
      expect(confirmada, isFalse);

      escritura.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        StackTrace.current,
      );
      await tester.pump();

      expect(destino.reportes, hasLength(1));
      expect(
        destino.reportes.single.tipo,
        'FirebaseException(cloud_firestore/permission-denied)',
      );
      expect(destino.reportes.single.motivo, contains('sincronizar'));
      expect(destino.reportes.single.fatal, isFalse);
    });
  });

  group('qué NO llega: datos personales', () {
    test('el mensaje de la excepción no sale del teléfono', () {
      CrashReporter.reportar(
        const FormatException('Monto inválido "150.000" de $_correo'),
        StackTrace.current,
        motivo: 'prueba',
      );
      CrashReporter.reportar(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing permissions for users/$_uid/transactions/tx1',
        ),
        StackTrace.current,
        motivo: 'prueba',
      );
      CrashReporter.reportar(
        StateError('El usuario $_uid no tiene perfil'),
        null,
        motivo: 'prueba',
      );

      final todo = destino.reportes.map((final r) => r.texto).join('\n');
      expect(todo, isNot(contains(_uid)));
      expect(todo, isNot(contains(_correo)));
      expect(todo, isNot(contains('150.000')));
      expect(destino.reportes.map((final r) => r.tipo), [
        'FormatException',
        'FirebaseException(cloud_firestore/permission-denied)',
        'StateError',
      ]);
    });

    test('un error de Flutter no manda el árbol de widgets ni su mensaje', () {
      final previo = FlutterError.onError;
      final previoPlataforma = PlatformDispatcher.instance.onError;
      CrashReporter.instalar(destino);
      final manejador = FlutterError.onError!;
      FlutterError.onError = previo;
      PlatformDispatcher.instance.onError = previoPlataforma;

      manejador(
        FlutterErrorDetails(
          exception: FlutterError('Desborde al pintar "Pedido de $_correo"'),
          stack: StackTrace.current,
          library: 'rendering library',
          context: ErrorDescription('al pintar la venta de $_uid'),
          informationCollector: () => [
            ErrorDescription('Text("Pedido de $_correo")'),
          ],
        ),
      );

      final todo = destino.reportes.map((final r) => r.texto).join('\n');
      expect(todo, isNot(contains(_uid)));
      expect(todo, isNot(contains(_correo)));
      expect(destino.reportes.single.motivo, 'rendering library');
    });

    test('sin destino instalado (debug, tests) reportar no hace nada', () {
      CrashReporter.destino = null;
      CrashReporter.reportar(StateError('x'), null, motivo: 'prueba');
      expect(destino.reportes, isEmpty);
    });
  });

  group('sin Analytics y sin identificar al usuario', () {
    String leer(final String ruta) => File(ruta).readAsStringSync();

    Iterable<File> fuentesDart() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((final f) => f.path.endsWith('.dart'));

    /// El código de [f] sin sus comentarios: un comentario que explica que
    /// algo NO se usa no cuenta como usarlo.
    String codigoDe(final File f) => f
        .readAsLinesSync()
        .where((final l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('Analytics no es una dependencia, ni directa ni transitiva', () {
      expect(leer('pubspec.yaml'), isNot(contains('firebase_analytics')));
      expect(leer('pubspec.lock'), isNot(contains('firebase_analytics')));
      expect(
        leer('android/app/build.gradle.kts'),
        isNot(contains('firebase-analytics')),
      );
    });

    test('ningún archivo le pasa a Crashlytics un identificador ni texto libre',
        () {
      // Son las tres formas de adjuntar datos propios a un informe:
      // identificador de usuario, claves personalizadas y líneas de log.
      final prohibido = RegExp(
        r'setUserIdentifier|setCustomKey|FirebaseCrashlytics\.instance\.log\b',
      );
      final culpables = [
        for (final f in fuentesDart())
          if (prohibido.hasMatch(codigoDe(f))) f.path,
      ];
      expect(culpables, isEmpty);
    });

    test('Crashlytics solo se toca desde crash_reporter.dart', () {
      final conCrashlytics = [
        for (final f in fuentesDart())
          if (codigoDe(f).contains('FirebaseCrashlytics'))
            f.path.replaceAll(r'\', '/'),
      ];
      expect(conCrashlytics, ['lib/core/services/crash_reporter.dart']);
    });
  });
}
