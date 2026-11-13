// PROPÓSITO: que los enlaces legales abran de verdad, y que un 404 se cuente
// en vez de dejar al usuario en una página de error.
//
// EL DEFECTO QUE ARREGLA: `url_launcher` no estaba en `pubspec.yaml`, así que
// la línea legal de Bienvenida —"Al continuar aceptas los Términos y la
// Política de privacidad"— se limitaba a COPIAR la dirección al portapapeles.
// El usuario aceptaba un texto que no podía leer desde el teléfono.
//
// Y como la landing todavía no está publicada, esas URLs devuelven 404: abrir
// el navegador a secas lo habría dejado mirando el 404 de GitHub.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_links.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/utils/app_feedback.dart';
import 'package:pagate_ia/core/utils/url_opener.dart';

void main() {
  late List<Uri> lanzadas;
  late List<Uri> comprobadas;
  late List<MethodCall> portapapeles;

  setUp(() {
    lanzadas = [];
    comprobadas = [];
    portapapeles = [];

    debugLanzadorDeEnlaces = (final uri) async {
      lanzadas.add(uri);
      return true;
    };
    debugComprobadorDeEnlaces = (final uri) async {
      comprobadas.add(uri);
      return 200;
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (final llamada) async {
      if (llamada.method == 'Clipboard.setData') portapapeles.add(llamada);
      return null;
    });
  });

  tearDown(() {
    AppFeedback.dismiss();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Monta una pantalla y devuelve el resultado de abrir [url] desde ella.
  Future<ResultadoEnlace> abrir(
    final WidgetTester tester,
    final String url,
  ) async {
    late ResultadoEnlace resultado;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (final context) => ElevatedButton(
              onPressed: () async =>
                  resultado = await abrirEnlaceExterno(context, url),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    // Dos frames y el tiempo de entrada del aviso. NO `pumpAndSettle`: el
    // aviso vive por una animacion, y asentarlo todo lo haria desaparecer
    // antes de que el test pueda comprobar que apareció.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    return resultado;
  }

  testWidgets('una página publicada se abre en el navegador', (
    final tester,
  ) async {
    final resultado = await abrir(tester, kUrlTerminos);

    expect(resultado, ResultadoEnlace.abierto);
    expect(lanzadas.single.toString(), kUrlTerminos);
    expect(portapapeles, isEmpty, reason: 'no hace falta copiar nada');
  });

  testWidgets('un 404 se dice, no se abre, y deja el enlace copiado', (
    final tester,
  ) async {
    // Es el estado REAL hasta que el dueño publique la landing.
    debugComprobadorDeEnlaces = (final uri) async {
      comprobadas.add(uri);
      return 404;
    };

    final resultado = await abrir(tester, kUrlPrivacidad);

    expect(resultado, ResultadoEnlace.noPublicado);
    expect(lanzadas, isEmpty, reason: 'no se expulsa al usuario a un 404');
    expect(portapapeles, hasLength(1));
    expect(
      find.textContaining('todavía no está publicada'),
      findsOneWidget,
    );
  });

  testWidgets('si no se puede comprobar, se abre igual', (
    final tester,
  ) async {
    // Sin red, DNS caído o CORS en web: no saber el estado no es motivo para
    // no abrir nada.
    debugComprobadorDeEnlaces = (final uri) async => null;

    final resultado = await abrir(tester, kUrlBorradoCuenta);

    expect(resultado, ResultadoEnlace.abierto);
    expect(lanzadas, hasLength(1));
  });

  testWidgets('sin navegador se avisa y se copia', (final tester) async {
    debugLanzadorDeEnlaces = (final uri) async => false;

    final resultado = await abrir(tester, kUrlTerminos);

    expect(resultado, ResultadoEnlace.sinNavegador);
    expect(portapapeles, hasLength(1));
    expect(find.textContaining('No se pudo abrir el navegador'), findsOneWidget);
  });

  testWidgets('si el lanzador revienta, se trata como un fallo normal', (
    final tester,
  ) async {
    debugLanzadorDeEnlaces = (final uri) async =>
        throw PlatformException(code: 'ACTIVITY_NOT_FOUND');

    final resultado = await abrir(tester, kUrlTerminos);

    expect(resultado, ResultadoEnlace.sinNavegador);
    expect(find.textContaining('No se pudo abrir el navegador'), findsOneWidget);
  });

  testWidgets('una URL sin esquema se rechaza antes de tocar la red', (
    final tester,
  ) async {
    final resultado = await abrir(tester, 'pagate.cl/terminos');

    expect(resultado, ResultadoEnlace.urlInvalida);
    expect(comprobadas, isEmpty);
    expect(lanzadas, isEmpty);
  });

  test('las tres direcciones apuntan a la landing publicada', () {
    // Son las rutas que existen de verdad en `landing-page/`: `terminos/`,
    // `privacidad/` y `eliminar-cuenta/`, cada una con su index.html.
    for (final url in [kUrlTerminos, kUrlPrivacidad, kUrlBorradoCuenta]) {
      expect(url, startsWith('https://'));
      expect(url, endsWith('/'));
      expect(url, contains(kUrlLandingBase));
    }
    expect(kUrlTerminos, endsWith('/terminos/'));
    expect(kUrlPrivacidad, endsWith('/privacidad/'));
    expect(kUrlBorradoCuenta, endsWith('/eliminar-cuenta/'));
  });
}
