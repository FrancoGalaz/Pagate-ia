// AppShell fija el idioma de Material en es_CL.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/utils/app_feedback.dart';
import 'package:pagate_ia/core/utils/escritura_pendiente.dart';
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

  // Revisión prelanzamiento 5.1: el rechazo tardío de algo guardado sin
  // conexión llega cuando la pantalla que lo guardó ya no existe. Lo pinta
  // la app, encima de lo que esté abierto.
  testWidgets('avisa en pantalla lo que el servidor rechazó al sincronizar', (
    final tester,
  ) async {
    await tester.pumpWidget(
      const AppShell(sessionKey: 'prueba', home: Scaffold()),
    );

    expect(RechazoAlSincronizar.avisar, isNotNull);
    RechazoAlSincronizar.avisar!('No se pudo guardar la ficha «Greda».');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('No se pudo guardar la ficha «Greda».'), findsOneWidget);

    AppFeedback.dismiss();
    await tester.pumpWidget(const SizedBox());
    expect(
      RechazoAlSincronizar.avisar,
      isNull,
      reason: 'sin app no queda nadie a quien avisar',
    );
  });
}
