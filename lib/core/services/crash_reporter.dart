import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════
// INFORMES DE FALLOS (prueba cerrada)
//
// Un error de Dart no cierra la app: deja una pantalla gris o un botón que no
// hace nada, y Play Console no lo ve. Sin esto no hay forma de saber qué les
// falla a los probadores.
//
// QUÉ SALE DEL TELÉFONO, Y QUÉ NO. La política de privacidad lo enumera y
// `test/core/services/crash_reporter_test.dart` lo vigila:
//
//   - SALE el TIPO del error (`StateError`, o
//     `FirebaseException(cloud_firestore/permission-denied)`), la traza del
//     código y de dónde vino. Crashlytics añade por su cuenta el modelo del
//     teléfono, la versión de Android y de la app y un identificador de
//     instalación.
//   - NO SALE el mensaje de la excepción ni el árbol de widgets: los dos
//     pueden citar lo que el usuario escribió, su correo o la ruta
//     `users/{uid}/...`.
//   - NO se llama a `setUserIdentifier`, `setCustomKey` ni `log`: un informe
//     no se puede asociar a una cuenta. Y no hay Analytics.
//
// Todo pasa por [CrashReporter.reportar]. Este es el ÚNICO archivo que toca
// Crashlytics.
// ═══════════════════════════════════════════════════════════════════════

/// Destino de los informes. En la app es [CrashlyticsSink]; en los tests, un
/// doble.
abstract class CrashSink {
  void record(
    String tipo,
    StackTrace? traza, {
    required String motivo,
    required bool fatal,
  });
}

/// El destino real: Firebase Crashlytics.
class CrashlyticsSink implements CrashSink {
  const CrashlyticsSink();

  @override
  void record(
    final String tipo,
    final StackTrace? traza, {
    required final String motivo,
    required final bool fatal,
  }) {
    // `printDetails: false`: en release no hay consola, y en ningún caso se
    // quiere el volcado de detalles.
    FirebaseCrashlytics.instance
        .recordError(
          tipo,
          traza,
          reason: motivo,
          fatal: fatal,
          printDetails: false,
        )
        .ignore();
  }
}

/// Informe de fallos de la app.
class CrashReporter {
  CrashReporter._();

  /// `null` mientras no se instala (debug, emuladores, tests): [reportar] no
  /// hace nada.
  static CrashSink? destino;

  /// Activa Crashlytics y engancha los errores de Flutter.
  ///
  /// Solo en un build de release y fuera de la web (Crashlytics no existe
  /// ahí): un build de debug o contra los emuladores no manda nada, y deja la
  /// recolección apagada para que tampoco salgan los cierres nativos.
  static Future<void> activar({required final bool contraEmuladores}) async {
    if (kIsWeb) return;
    final enviar = kReleaseMode && !contraEmuladores;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enviar);
    if (enviar) instalar(const CrashlyticsSink());
  }

  /// Manda a [sink] los errores de Flutter y los que nadie capturó.
  static void instalar(final CrashSink sink) {
    destino = sink;

    FlutterError.onError = (final details) {
      reportar(
        details.exception,
        details.stack,
        // Solo la librería de Flutter donde ocurrió («widgets library»). El
        // `context` y el `informationCollector` no: describen el árbol de
        // widgets, con sus textos.
        motivo: details.library ?? 'Flutter',
        fatal: true,
      );
      FlutterError.presentError(details);
    };

    // Los errores asíncronos que nadie capturó: sin esto se pierden.
    PlatformDispatcher.instance.onError = (final error, final stack) {
      reportar(error, stack, motivo: 'sin capturar', fatal: true);
      return true;
    };
  }

  /// Reporta [error] por su TIPO, nunca por su mensaje.
  static void reportar(
    final Object error,
    final StackTrace? traza, {
    required final String motivo,
    final bool fatal = false,
  }) {
    destino?.record(tipoDe(error), traza, motivo: motivo, fatal: fatal);
  }

  /// La clase del error y, si es de Firebase, su código. Es todo lo que se
  /// dice de él.
  static String tipoDe(final Object error) => error is FirebaseException
      ? 'FirebaseException(${error.plugin}/${error.code})'
      : '${error.runtimeType}';
}
