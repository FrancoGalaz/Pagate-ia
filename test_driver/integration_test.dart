// Driver de `flutter drive` para integration_test/capturas_test.dart: guarda
// cada captura como PNG en la máquina, en la carpeta de CAPTURAS_DIR.

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final carpeta = Platform.environment['CAPTURAS_DIR'] ?? 'capturas/sin-fecha';
  await integrationDriver(
    onScreenshot: (final nombre, final bytes, [final args]) async {
      final archivo = File('$carpeta/$nombre.png');
      await archivo.create(recursive: true);
      await archivo.writeAsBytes(bytes);
      return true;
    },
  );
}
