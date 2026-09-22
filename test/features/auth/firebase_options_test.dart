// DefaultFirebaseOptions no toca Firebase: solo elige constantes por
// plataforma. Se prueba forzando defaultTargetPlatform.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/firebase_options.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('en Android devuelve las opciones de google-services.json', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final options = DefaultFirebaseOptions.currentPlatform;

    expect(options, same(DefaultFirebaseOptions.android));
    expect(options.projectId, 'pagate-17211');
    expect(options.messagingSenderId, '390581596119');
    expect(options.appId, '1:390581596119:android:6d160588213047dfffa592');
    expect(options.apiKey, isNot(contains('...')));
  });

  test('en plataformas no configuradas lanza UnsupportedError', () {
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        () => DefaultFirebaseOptions.currentPlatform,
        throwsUnsupportedError,
        reason: '$platform deberia fallar con mensaje claro',
      );
    }
  });

  test('web sigue pendiente hasta que el dueño complete F0-01', () {
    expect(DefaultFirebaseOptions.webIsConfigured, isFalse);
  });
}
