// Prueba de humo del sistema visual, sin Firebase.
//
// Los widget tests por componente viven en `test/core/widgets/`, uno por
// archivo, como manda el paso R-5 de docs/DISENO-v2.md. Aquí queda lo que no
// pertenece a ningún componente: que el barrel exporte el sistema completo y
// que el tema monte.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';

void main() {
  testWidgets('el tema claro monta y pinta el lienzo del sistema', (
    final tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: PagatePrimaryButton(label: 'Continuar', onPressed: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Continuar'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNull,
        reason: 'el fondo lo pone el tema, no la pantalla');
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      const Color(0xFFF6F7F8),
    );
  });
}
