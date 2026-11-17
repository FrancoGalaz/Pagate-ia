// SessionErrorView: mensaje para la persona; la excepción solo en debug.

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/firebase_auth_service.dart';
import 'package:pagate_ia/features/auth/presentation/pages/auth_gate.dart';
import 'package:pagate_ia/features/auth/presentation/widgets/session_error_view.dart';
import 'package:provider/provider.dart';

Future<void> _montar(
  final WidgetTester tester, {
  required final bool mostrarDetalle,
}) => tester.pumpWidget(
  MaterialApp(
    home: SessionErrorView(
      message: 'No pudimos comprobar tu sesión.',
      detail: StateError('token roto'),
      onRetry: () {},
      mostrarDetalle: mostrarDetalle,
    ),
  ),
);

class _AuthConError extends ChangeNotifier implements FirebaseAuthService {
  @override
  Stream<User?> get authStateChanges => Stream.error(StateError('token roto'));

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  testWidgets('en release muestra el mensaje y Reintentar, sin la excepción', (
    final tester,
  ) async {
    await _montar(tester, mostrarDetalle: false);

    expect(find.text('No pudimos comprobar tu sesión.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.textContaining('token roto'), findsNothing);
  });

  testWidgets('en debug muestra además el detalle', (final tester) async {
    await _montar(tester, mostrarDetalle: true);

    expect(find.textContaining('token roto'), findsOneWidget);
  });

  testWidgets('AuthGate ya no mete la excepción dentro del mensaje', (
    final tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FirebaseAuthService>.value(
        value: _AuthConError(),
        child: const AuthGate(),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'No pudimos comprobar tu sesión. Revisa tu conexión e inténtalo de '
        'nuevo.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('sesión: '), findsNothing);
  });

  testWidgets('AuthGate registra el error una sola vez, no en cada build', (
    final tester,
  ) async {
    final registro = <String?>[];
    final original = debugPrint;
    debugPrint = (final message, {final wrapWidth}) => registro.add(message);
    try {
      final auth = _AuthConError();
      Future<void> montar() => tester.pumpWidget(
        ChangeNotifierProvider<FirebaseAuthService>.value(
          value: auth,
          // Sin const: cada pumpWidget vuelve a construir el AuthGate.
          // ignore: prefer_const_constructors
          child: AuthGate(),
        ),
      );
      await montar();
      await tester.pump();
      await montar();
      await montar();
    } finally {
      debugPrint = original;
    }

    expect(
      registro.where((final m) => m!.contains('[AuthGate]')),
      hasLength(1),
    );
  });
}
