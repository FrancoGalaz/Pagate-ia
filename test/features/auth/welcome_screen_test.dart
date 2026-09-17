// Renderiza WelcomeScreen sin Firebase (solo navegacion local).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/features/auth/presentation/pages/welcome_screen.dart';

void main() {
  testWidgets('WelcomeScreen renderiza el titulo y el CTA principal', (
    final tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const WelcomeScreen()),
    );
    await tester.pump();

    expect(find.text('Págate-IA'), findsOneWidget);
    expect(find.text('Empezar ahora (Gratis)'), findsOneWidget);
  });
}
