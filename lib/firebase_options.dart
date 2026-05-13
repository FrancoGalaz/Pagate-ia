import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSy...r-vA',
    appId: '1:390581596119:android:6d160588213047dfffa592',
    messagingSenderId: '390581596119',
    projectId: 'pagate-17211',
    storageBucket: 'pagate-17211.firebasestorage.app',
  );

  /// Web Firebase configuration.
  ///
  /// ⚠️ ACTUALIZA ESTOS VALORES DESDE FIREBASE CONSOLE:
  /// 1. Ve a https://console.firebase.google.com/project/pagate-17211/settings/general
  /// 2. En "Your apps" → "Add app" → "Web"
  /// 3. Copia el firebaseConfig y pega los valores aquí
  /// 4. O usa: firebase apps:create WEB pagate-ia-web
  ///    luego: firebase apps:sdkconfig WEB
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSy...r-vA',                     // 🔁 REEMPLAZA con Web API Key
    appId: '1:390581596119:web:xxxxxxxxxxxx',    // 🔁 REEMPLAZA con Web App ID
    messagingSenderId: '390581596119',
    projectId: 'pagate-17211',
    authDomain: 'pagate-17211.firebaseapp.com',
    storageBucket: 'pagate-17211.firebasestorage.app',
  );
}
