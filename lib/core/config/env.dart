import 'package:flutter/foundation.dart';

/// Configuración de entorno resuelta en tiempo de compilación vía `--dart-define`.
///
/// - `PAGATE_ENV=dev|prod` (default `prod`). En `dev` el cliente usa los
///   emuladores locales de Firebase.
/// - `APP_CHECK_SITE_KEY=...` site key de reCAPTCHA v3 para App Check en web.
class Env {
  Env._();

  static const String env = String.fromEnvironment(
    'PAGATE_ENV',
    defaultValue: 'prod',
  );

  static bool get isDev => env == 'dev';

  static const String appCheckSiteKey = String.fromEnvironment(
    'APP_CHECK_SITE_KEY',
  );

  static const String functionsRegion = 'southamerica-west1';

  static const int authEmulatorPort = 9099;
  static const int firestoreEmulatorPort = 8080;
  static const int functionsEmulatorPort = 5001;

  /// Host de los emuladores. El emulador de Android ve a la máquina anfitriona
  /// como `10.0.2.2`; el resto de plataformas usa `localhost`.
  static String get emulatorHost {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }
}
