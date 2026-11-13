import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones de Firebase por plataforma para el proyecto `pagate-17211`.
///
/// Solo Android y web están configuradas. Cualquier otra plataforma lanza
/// [UnsupportedError] en [currentPlatform] para que el arranque falle con un
/// mensaje claro (y caiga en `BootstrapErrorApp`) en vez de correr con las
/// credenciales de Android.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para '
          '$defaultTargetPlatform',
        );
    }
  }

  /// Valores tomados de `android/app/google-services.json`
  /// (`client[0].api_key[0].current_key` y
  /// `client[0].client_info.mobilesdk_app_id`). Si ese archivo cambia,
  /// actualizar aquí también.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDNtdgCov0WpdZnyUhhdDHp1yewnHdr-vA',
    appId: '1:390581596119:android:6d160588213047dfffa592',
    messagingSenderId: '390581596119',
    projectId: 'pagate-17211',
    storageBucket: 'pagate-17211.firebasestorage.app',
  );

  /// Configuración web: PENDIENTE (tarea F0-01, solo el dueño del proyecto).
  ///
  /// Faltan `apiKey` y `appId` de la app web. Se obtienen con
  /// `flutterfire configure --project=pagate-17211 --platforms=android,web`
  /// o desde Firebase Console → Configuración del proyecto → Tus apps → Web.
  /// Mientras tanto [webIsConfigured] devuelve `false` y el arranque en web
  /// falla con un mensaje claro en vez de arrancar con credenciales falsas.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSy...r-vA', // PENDIENTE: Web API Key
    appId: '1:390581596119:web:xxxxxxxxxxxx', // PENDIENTE: Web App ID
    messagingSenderId: '390581596119',
    projectId: 'pagate-17211',
    authDomain: 'pagate-17211.firebaseapp.com',
    storageBucket: 'pagate-17211.firebasestorage.app',
  );

  /// `true` cuando [web] tiene un `appId` real (ya no es el placeholder).
  static bool get webIsConfigured => !web.appId.contains('xxxx');
}
