// Widget test de WelcomeScreen, sin Firebase (solo navegación local).
//
// Especificación: docs/DISENO-v2.md, "Pantalla de bienvenida".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_brand.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';
import 'package:pagate_ia/features/auth/presentation/pages/welcome_screen.dart';

Future<void> _montar(
  final WidgetTester tester, {
  final double textScale = 1.0,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WelcomeScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('cuenta qué hace la app y ofrece una sola acción', (
    final tester,
  ) async {
    await _montar(tester);

    // El nombre de la marca es UNO en toda la app, y es el que el usuario
    // ve bajo el icono en su teléfono (res/values/strings.xml). Antes esta
    // pantalla decía "Págate" y el login "Págate-IA".
    expect(find.text(kAppName), findsOneWidget);
    expect(
      find.text('Saber cuánto ganas cada mes\ny cuánto vale tu hora.'),
      findsOneWidget,
    );
    expect(find.text('Crear cuenta'), findsOneWidget);

    // Un único botón de arranque. Antes había dos opciones y la única que
    // llegaba a renderizarse en Android era el botón de Apple, que solo
    // mostraba "todavía no está disponible": un botón muerto en la primera
    // pantalla del APK que va a Play.
    expect(find.byType(PagateSocialButton), findsNothing);
    expect(find.textContaining('Apple'), findsNothing);
    expect(find.byType(PagatePrimaryButton), findsOneWidget);
  });

  testWidgets('no muestra ni una cifra ni una afirmación inventada', (
    final tester,
  ) async {
    await _montar(tester);

    // Las dos tarjetas flotantes enseñaban "+24%" y "Optimizado" con la
    // forma de un dato real del negocio del usuario, en la pantalla donde
    // todavía no hay usuario. Ninguno salía de Firestore.
    for (final inventado in ['+24%', 'GANANCIA', 'STOCK', 'Optimizado']) {
      expect(find.text(inventado), findsNothing, reason: inventado);
    }

    // Afirmación de primacía no verificable: material de rechazo en Play.
    expect(find.textContaining('La primera herramienta'), findsNothing);

    // El precio va en la ficha de Play, no dentro de un botón.
    expect(find.textContaining('Gratis'), findsNothing);
  });

  testWidgets('las tres pruebas corresponden a features que existen', (
    final tester,
  ) async {
    await _montar(tester);

    expect(find.text('Ingresos y gastos del mes, al día'), findsOneWidget);
    expect(find.text('Valor de tu hora según tus horas reales'), findsOneWidget);
    expect(find.text('Reporte en PDF para tu contador'), findsOneWidget);
  });

  testWidgets('todo queda alineado a la izquierda', (final tester) async {
    await _montar(tester);

    // Antes no quedaba un solo elemento alineado a la izquierda. El
    // wordmark se mide por su cuadrado de marca, no por el texto, que va
    // detrás de él.
    expect(
      tester.getTopLeft(find.byType(Container).first).dx,
      AppSpacing.x4,
      reason: 'wordmark',
    );

    // Las tres pruebas se miden por su icono: el texto va detrás de él.
    expect(
      tester.getTopLeft(find.byIcon(Icons.picture_as_pdf_outlined)).dx,
      AppSpacing.x4,
      reason: 'prueba del PDF',
    );

    for (final texto in [
      'Saber cuánto ganas cada mes\ny cuánto vale tu hora.',
      'Al continuar aceptas los ',
    ]) {
      expect(
        tester.getTopLeft(find.textContaining(texto)).dx,
        AppSpacing.x4,
        reason: texto,
      );
    }
  });

  testWidgets('la línea legal nombra los dos textos y no es un adorno', (
    final tester,
  ) async {
    await _montar(tester);

    expect(
      find.textContaining('Al continuar aceptas los Términos'),
      findsOneWidget,
    );

    // Lo que había: la línea afirmaba que el usuario aceptaba unos términos
    // y el botón de al lado respondía "puedes revisarlos desde
    // configuración", donde no existe ninguna sección de términos.
    expect(find.text('Ver términos'), findsNothing);
  });

  testWidgets('no lleva sombras, degradados ni desenfoques', (
    final tester,
  ) async {
    await _montar(tester);

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
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('no desborda con el ajuste Grande de Android (1,3x)', (
    final tester,
  ) async {
    await _montar(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no desborda a 2,0x en una pantalla de 360 dp', (
    final tester,
  ) async {
    await _montar(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);
  });
}
