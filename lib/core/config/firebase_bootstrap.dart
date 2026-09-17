import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'env.dart';

/// Inicializa Firebase, habilita la persistencia offline de Firestore,
/// conecta los emuladores cuando `PAGATE_ENV=dev` y activa App Check.
///
/// App Check nunca impide el arranque: cualquier fallo se registra con
/// [debugPrint] y la app continúa.
Future<void> bootstrapFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  _enableFirestorePersistence();

  if (Env.isDev) {
    await _connectEmulators();
  }

  await _activateAppCheck();
}

/// `Settings.persistenceEnabled` cubre nativo y web en cloud_firestore 5.x
/// (en web activa la caché IndexedDB al primer uso; `enablePersistence()`
/// está deprecado). Debe fijarse antes de cualquier uso de Firestore.
void _enableFirestorePersistence() {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    debugPrint('[Firestore] No se pudo habilitar la persistencia offline: $e');
  }
}

Future<void> _connectEmulators() async {
  final host = Env.emulatorHost;
  debugPrint('[Firebase] PAGATE_ENV=dev: usando emuladores en $host');

  await FirebaseAuth.instance.useAuthEmulator(host, Env.authEmulatorPort);
  FirebaseFirestore.instance.useFirestoreEmulator(
    host,
    Env.firestoreEmulatorPort,
  );

  try {
    FirebaseFunctions.instanceFor(region: Env.functionsRegion)
        .useFunctionsEmulator(host, Env.functionsEmulatorPort);
  } catch (e) {
    // cloud_functions no tiene soporte en todas las plataformas de escritorio.
    debugPrint('[Functions] No se pudo conectar al emulador: $e');
  }
}

Future<void> _activateAppCheck() async {
  try {
    ReCaptchaV3Provider? webProvider;
    if (kIsWeb) {
      if (Env.appCheckSiteKey.isEmpty) {
        debugPrint(
          '[AppCheck] Falta APP_CHECK_SITE_KEY: App Check no se activa en web.',
        );
        return;
      }
      webProvider = ReCaptchaV3Provider(Env.appCheckSiteKey);
    }

    await FirebaseAppCheck.instance.activate(
      webProvider: webProvider,
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (e) {
    debugPrint('[AppCheck] No se pudo activar App Check; la app continúa: $e');
  }
}
