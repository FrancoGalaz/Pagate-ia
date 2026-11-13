// Arnés común de los widget tests de `lib/core/widgets/`.
//
// Monta un componente dentro de `MaterialApp` + `AppTheme.lightTheme`, que
// es como se renderiza en la app de verdad: casi todo el sistema visual vive
// en el tema, así que un componente probado fuera de él no prueba nada.
//
// Sin Firebase, como manda AGENTS.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';

/// Monta [child] en una pantalla con el tema de la app.
///
/// [width] fija el ancho del lienzo. Por defecto 360 dp, el ancho de un móvil
/// estrecho corriente, que es donde aparecen los desbordes.
///
/// [textScale] permite repetir el mismo test con el ajuste de fuente del
/// sistema subido. El 1,3 es el ajuste "Grande" de Android, el más común
/// fuera del 100%, y es el que hoy desborda la pantalla de Inicio.
Future<void> pumpComponent(
  final WidgetTester tester,
  final Widget child, {
  final double width = 360,
  final double height = 800,
  final double textScale = 1.0,
}) async {
  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    ),
  );
}

/// Falla si la pasada anterior lanzó algo, que en la práctica es siempre un
/// `RenderFlex overflowed`.
///
/// `takeException` consume la excepción, así que tiene que llamarse una sola
/// vez y después de la pasada que se quiere comprobar.
void esperarSinDesborde(final WidgetTester tester) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'El componente desbordó al renderizar',
  );
}
