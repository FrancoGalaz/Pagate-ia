// PROPÓSITO: que la app vuelva a tener UNA marca y UN nombre.
//
// Había tres nombres y dos dibujos a la vista en el primer minuto de uso:
// "Págate" con un cuadrado sólido en la bienvenida y en el rail, "Págate-IA"
// con un rayo sobre un degradado en el login y en el splash, y "Págate-IA"
// bajo el icono del lanzador. El porqué del nombre elegido está en
// `lib/core/constants/app_brand.dart`.
//
// Este test falla si alguien vuelve a escribir el nombre a mano en una
// pantalla o si la marca recupera el degradado y la sombra.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_brand.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';
import 'package:pagate_ia/features/auth/presentation/pages/splash_screen.dart';

import 'harness.dart';

void main() {
  test('el nombre de la app es el del lanzador de Android', () {
    // `android:label` apunta a `app_name` en res/values/strings.xml, que es
    // el texto que el usuario ve bajo el icono. Si los dos dejan de
    // coincidir, la app instalada se llama distinto que sus términos de uso.
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();

    expect(
      strings,
      contains('<string name="app_name">$kAppName</string>'),
      reason: 'el nombre de la app y el del lanzador tienen que coincidir',
    );
  });

  test('ninguna pantalla escribe el nombre a mano', () {
    // Se permite en `app_brand.dart` (es donde vive) y en comentarios, que
    // explican qué nombres había antes.
    final culpables = <String>[];
    for (final fuente in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((final f) => f.path.endsWith('.dart'))) {
      if (fuente.path.endsWith('app_brand.dart')) continue;

      final lineas = fuente.readAsStringSync().split('\n');
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        final codigo = linea.contains('//')
            ? linea.substring(0, linea.indexOf('//'))
            : linea;
        if (codigo.contains('Págate')) {
          culpables.add('${fuente.path}:${i + 1}: ${linea.trim()}');
        }
      }
    }
    expect(
      culpables,
      isEmpty,
      reason: 'usa kAppName:\n${culpables.join('\n')}',
    );
  });

  testWidgets('la marca dibuja el nombre y un cuadrado plano', (
    final tester,
  ) async {
    await pumpComponent(tester, const PagateWordmark());

    expect(find.text(kAppName), findsOneWidget);

    // Ni degradado ni sombra: el cuadrado es un relleno plano de marca.
    expect(
      find.byWidgetPredicate(
        (final w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).gradient != null ||
                ((w.decoration as BoxDecoration).boxShadow?.isNotEmpty ??
                    false)),
      ),
      findsNothing,
    );
  });

  testWidgets('la marca no desborda a 2,0x en 360 dp', (final tester) async {
    // A 2,0x de fuente del sistema, "Págate-IA" en `headlineMedium` medía más
    // que el ancho de la pantalla y la fila de la bienvenida se salía 66 px.
    await pumpComponent(
      tester,
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: PagateWordmark(size: PagateWordmarkSize.grande),
      ),
      textScale: 2.0,
    );
    esperarSinDesborde(tester);
  });

  testWidgets('la pantalla de espera usa la marca del sistema', (
    final tester,
  ) async {
    // No se puede fotografiar en el emulador: dura los pocos fotogramas que
    // tarda `authStateChanges` en resolver contra el emulador local. Esto es
    // lo que comprueba que ya no dibuja su propio rayo sobre un degradado.
    await pumpComponent(tester, const SplashScreen());

    expect(find.byType(PagateWordmark), findsOneWidget);
    expect(find.text(kAppName), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
