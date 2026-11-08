import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/firebase_auth_service.dart';
import 'package:pagate_ia/features/auth/presentation/pages/auth_gate.dart';
import 'package:pagate_ia/features/auth/presentation/pages/splash_screen.dart';
import 'package:pagate_ia/features/auth/presentation/widgets/cerrar_sesion.dart';
import 'package:pagate_ia/features/auth/presentation/widgets/user_scope.dart';
import 'package:provider/provider.dart';

/// Anota en [registro] lo que se le pide a Auth.
class _AuthFalso extends Fake implements FirebaseAuth {
  _AuthFalso(this.registro);
  final List<String> registro;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> userChanges() => const Stream.empty();

  @override
  Future<void> signOut() async => registro.add('signOut');

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required final String email,
    required final String password,
  }) async =>
      _CredencialFalsa();
}

class _CredencialFalsa extends Fake implements UserCredential {}

/// Anota en [registro] lo que se le pide a Firestore. Con [pendientes],
/// `waitForPendingWrites` no termina nunca (como sin conexión).
class _FirestoreFalso extends Fake implements FirebaseFirestore {
  _FirestoreFalso(this.registro, {this.pendientes = false, this.fallaBorrar});
  final List<String> registro;
  final bool pendientes;
  final Object? fallaBorrar;

  @override
  Future<void> waitForPendingWrites() {
    registro.add('waitForPendingWrites');
    return pendientes ? Completer<void>().future : Future.value();
  }

  @override
  Future<void> terminate() async => registro.add('terminate');

  @override
  Future<void> clearPersistence() async {
    registro.add('clearPersistence');
    if (fallaBorrar != null) throw fallaBorrar!;
  }
}

class _UsuarioFalso extends Fake implements User {
  @override
  String get uid => 'uid-a';
}

void main() {
  late List<String> registro;

  FirebaseAuthService servicio({
    final bool pendientes = false,
    final Object? fallaBorrar,
  }) =>
      FirebaseAuthService(
        auth: _AuthFalso(registro),
        firestore: _FirestoreFalso(
          registro,
          pendientes: pendientes,
          fallaBorrar: fallaBorrar,
        ),
      );

  setUp(() => registro = []);

  group('cerrarSesion', () {
    testWidgets(
        'sin aviso (tras deleteAccount): no espera pendientes y borra la '
        'caché antes de signOut', (final tester) async {
      final s = servicio(pendientes: true);

      final cierre = s.cerrarSesion();
      expect(s.cerrandoSesion, isTrue);
      expect(registro, isEmpty, reason: 'espera un frame antes de terminate');
      await tester.pump();

      expect(await cierre, isTrue);
      expect(registro, ['terminate', 'clearPersistence', 'signOut']);
    });

    testWidgets('signOut se ejecuta aunque clearPersistence falle', (
      final tester,
    ) async {
      final s = servicio(fallaBorrar: Exception('caché ocupada'));

      final cierre = s.cerrarSesion();
      await tester.pump();

      expect(await cierre, isTrue);
      expect(registro, ['terminate', 'clearPersistence', 'signOut']);
    });

    testWidgets('sin pendientes no pregunta', (final tester) async {
      final s = servicio();
      var preguntas = 0;

      final cierre = s.cerrarSesion(
        confirmarPerdidaDeCambios: () async {
          preguntas++;
          return true;
        },
      );
      await tester.pump();
      await tester.pump();

      expect(await cierre, isTrue);
      expect(preguntas, 0);
      expect(registro, [
        'waitForPendingWrites',
        'terminate',
        'clearPersistence',
        'signOut',
      ]);
    });

    testWidgets('con pendientes tras 5 s pregunta; Cancelar no cierra nada', (
      final tester,
    ) async {
      final s = servicio(pendientes: true);
      var preguntas = 0;

      final cierre = s.cerrarSesion(
        confirmarPerdidaDeCambios: () async {
          preguntas++;
          return false;
        },
      );
      await tester.pump(const Duration(seconds: 4));
      expect(preguntas, 0);
      await tester.pump(const Duration(seconds: 1));

      expect(await cierre, isFalse);
      expect(preguntas, 1);
      expect(s.cerrandoSesion, isFalse);
      expect(registro, ['waitForPendingWrites']);
    });

    testWidgets('con pendientes y Cerrar igual, cierra y borra', (
      final tester,
    ) async {
      final s = servicio(pendientes: true);

      final cierre = s.cerrarSesion(confirmarPerdidaDeCambios: () async => true);
      await tester.pump(FirebaseAuthService.esperaEscriturasPendientes);
      await tester.pump();

      expect(await cierre, isTrue);
      expect(registro, [
        'waitForPendingWrites',
        'terminate',
        'clearPersistence',
        'signOut',
      ]);
    });

    testWidgets('iniciar sesión de nuevo baja cerrandoSesion', (
      final tester,
    ) async {
      final s = servicio();
      final cierre = s.cerrarSesion();
      await tester.pump();
      await cierre;
      expect(s.cerrandoSesion, isTrue);

      await s.signInWithEmailAndPassword(email: 'b@x.cl', password: 'clave1');

      expect(s.cerrandoSesion, isFalse);
    });
  });

  group('aviso de cambios sin sincronizar', () {
    Future<Future<bool>> abrir(final WidgetTester tester) async {
      late Future<bool> respuesta;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (final context) => TextButton(
              onPressed: () =>
                  respuesta = confirmarCierreSinSincronizar(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Tienes cambios sin sincronizar. Si cierras sesión sin conexión se '
          'perderán.',
        ),
        findsOneWidget,
      );
      return respuesta;
    }

    testWidgets('Cancelar devuelve false', (final tester) async {
      final respuesta = await abrir(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(await respuesta, isFalse);
    });

    testWidgets('Cerrar igual devuelve true', (final tester) async {
      final respuesta = await abrir(tester);
      await tester.tap(find.text('Cerrar igual'));
      await tester.pumpAndSettle();
      expect(await respuesta, isTrue);
    });
  });

  testWidgets(
      'AuthGate muestra el splash y no monta UserScope mientras se cierra '
      'la sesión', (final tester) async {
    final s = _ServicioCerrando();
    await tester.pumpWidget(
      ChangeNotifierProvider<FirebaseAuthService>.value(
        value: s,
        child: const AuthGate(),
      ),
    );
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(UserScope), findsNothing);
  });
}

/// Servicio con un usuario en el stream y [cerrandoSesion] en `true`: el
/// estado que deja `cerrarSesion` antes de llamar a `terminate`.
class _ServicioCerrando extends ChangeNotifier implements FirebaseAuthService {
  @override
  Stream<User?> get authStateChanges => Stream.value(_UsuarioFalso());

  @override
  bool get cerrandoSesion => true;

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}
