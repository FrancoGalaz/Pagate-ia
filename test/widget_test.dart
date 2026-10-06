// Widget test que no toca Firebase: renderiza un widget de core dentro de un
// MaterialApp con el tema de la app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';

void main() {
  testWidgets('PagatePrimaryButton muestra su etiqueta y responde al tap', (
    final tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: PagatePrimaryButton(
              label: 'Continuar',
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Continuar'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    expect(taps, 1);
  });

  testWidgets('PagatePrimaryButton en carga no responde al tap', (
    final tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PagatePrimaryButton(
            label: 'Guardar',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Guardar'), findsNothing);
    await tester.tap(find.byType(PagatePrimaryButton));
    expect(taps, 0);
  });
}
