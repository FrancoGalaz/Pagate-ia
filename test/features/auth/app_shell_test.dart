// AppShell fija el idioma de Material en es_CL.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/auth/presentation/widgets/app_shell.dart';

void main() {
  testWidgets('el selector de fecha y los textos de Material van en español', (
    final tester,
  ) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      AppShell(
        sessionKey: 'prueba',
        home: Builder(
          builder: (final context) {
            contexto = context;
            return const Scaffold();
          },
        ),
      ),
    );

    expect(Localizations.localeOf(contexto), const Locale('es', 'CL'));

    unawaited(
      showDatePicker(
        context: contexto,
        initialDate: DateTime(2026, 11, 8),
        firstDate: DateTime(2026),
        lastDate: DateTime(2027),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('ACEPTAR'), findsOneWidget);
    expect(find.textContaining('noviembre'), findsWidgets);
  });
}
