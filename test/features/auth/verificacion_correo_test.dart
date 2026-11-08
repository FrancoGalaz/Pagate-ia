// Verificación de correo: el servicio de auth, el aviso de Inicio, la marca
// del AiProvider y el acceso "Reenviar correo" del chat.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/ai_service.dart';
import 'package:pagate_ia/core/services/firebase_auth_service.dart';
import 'package:pagate_ia/features/auth/presentation/widgets/verificar_correo_banner.dart';
import 'package:pagate_ia/features/dashboard/presentation/pages/tabs/ia_tab.dart';
import 'package:pagate_ia/features/dashboard/presentation/providers/ai_provider.dart';
import 'package:provider/provider.dart';

// ─── Dobles de Firebase Auth ────────────────────────────────────────────────

class _UsuarioFalso extends Fake implements User {
  _UsuarioFalso(this.registro, {this.verificadoTrasRecargar = false});
  final List<String> registro;
  final bool verificadoTrasRecargar;
  bool _verificado = false;

  @override
  bool get emailVerified => _verificado;

  @override
  String? get email => 'ana@taller.cl';

  @override
  Future<void> updateDisplayName(final String? displayName) async {}

  @override
  Future<void> sendEmailVerification([
    final ActionCodeSettings? actionCodeSettings,
  ]) async => registro.add('sendEmailVerification');

  @override
  Future<void> reload() async {
    registro.add('reload');
    _verificado = verificadoTrasRecargar;
  }

  @override
  Future<String?> getIdToken([final bool forceRefresh = false]) async {
    registro.add('getIdToken($forceRefresh)');
    return 'token';
  }
}

class _Credencial extends Fake implements UserCredential {
  _Credencial(this.user);
  @override
  final User user;
}

class _AuthFalso extends Fake implements FirebaseAuth {
  _AuthFalso(this.usuario);
  final _UsuarioFalso usuario;
  bool conSesion = false;

  @override
  User? get currentUser => conSesion ? usuario : null;

  @override
  Stream<User?> userChanges() => const Stream.empty();

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required final String email,
    required final String password,
  }) async {
    conSesion = true;
    return _Credencial(usuario);
  }
}

// ─── Dobles para el chat ────────────────────────────────────────────────────

/// Firestore que falla al cargar el historial: el provider lo absorbe.
class _DbSinHistorial extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(final String path) =>
      throw StateError('sin historial en este test');
}

class _ChatQueRechaza implements AiService {
  _ChatQueRechaza(this.error);
  final AiServiceException error;

  @override
  Future<ChatReply> sendMessage({
    final String? conversationId,
    required final String message,
  }) async => throw error;

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _AuthServicioFalso extends ChangeNotifier implements FirebaseAuthService {
  _AuthServicioFalso({required this.correoVerificado});

  @override
  bool correoVerificado;

  @override
  String? get email => 'ana@taller.cl';

  int reenvios = 0;
  bool verificaAlComprobar = false;

  @override
  Future<void> reenviarVerificacion() async => reenvios++;

  @override
  Future<bool> comprobarVerificacion() async {
    correoVerificado = verificaAlComprobar;
    notifyListeners();
    return correoVerificado;
  }

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _AiSinVerificar extends ChangeNotifier implements AiProvider {
  @override
  List<ChatMessage> get messages => const [];
  @override
  bool get isSending => false;
  @override
  bool get isLoadingHistory => false;
  @override
  String? get conversationId => null;
  @override
  String? get error => 'Verifica tu correo para usar el asistente.';
  @override
  bool get canRetry => true;
  @override
  bool get faltaVerificarCorreo => true;
  @override
  bool isReported(final String messageId) => false;

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  group('FirebaseAuthService', () {
    test('registrarse envía el correo de verificación', () async {
      final registro = <String>[];
      final s = FirebaseAuthService(
        auth: _AuthFalso(_UsuarioFalso(registro)),
        firestore: _DbSinHistorial(),
      );

      await s.createUserWithEmailAndPassword(
        email: 'ana@taller.cl',
        password: 'clave-123456',
      );

      expect(registro, ['sendEmailVerification']);
    });

    test(
      'comprobarVerificacion recarga y pide un token nuevo si ya verificó',
      () async {
        final registro = <String>[];
        final auth = _AuthFalso(
          _UsuarioFalso(registro, verificadoTrasRecargar: true),
        )..conSesion = true;
        final s = FirebaseAuthService(auth: auth, firestore: _DbSinHistorial());
        expect(s.correoVerificado, isFalse);

        expect(await s.comprobarVerificacion(), isTrue);
        expect(s.correoVerificado, isTrue);
        expect(registro, ['reload', 'getIdToken(true)']);
      },
    );

    test('sin verificar, recarga pero no pide token', () async {
      final registro = <String>[];
      final auth = _AuthFalso(_UsuarioFalso(registro))..conSesion = true;
      final s = FirebaseAuthService(auth: auth, firestore: _DbSinHistorial());

      expect(await s.comprobarVerificacion(), isFalse);
      expect(registro, ['reload']);
    });
  });

  group('AiProvider', () {
    Future<AiProvider> conError(final String code) async {
      final p = AiProvider(
        service: _ChatQueRechaza(
          AiServiceException.from(
            code,
            'Verifica tu correo para usar el asistente. Te enviamos un enlace.',
          ),
        ),
        userId: 'uid-a',
        firestore: _DbSinHistorial(),
      );
      await Future<void>.delayed(Duration.zero);
      await p.sendMessage('Hola');
      return p;
    }

    test(
      'failed-precondition marca faltaVerificarCorreo y muestra el texto',
      () async {
        final p = await conError('failed-precondition');
        expect(p.faltaVerificarCorreo, isTrue);
        expect(p.error, contains('Verifica tu correo'));

        p.clearError();
        expect(p.faltaVerificarCorreo, isFalse);
      },
    );

    test('otro error no lo marca', () async {
      final p = await conError('unavailable');
      expect(p.faltaVerificarCorreo, isFalse);
    });
  });

  group('VerificarCorreoBanner', () {
    Future<_AuthServicioFalso> montar(
      final WidgetTester tester, {
      required final bool verificado,
    }) async {
      final auth = _AuthServicioFalso(correoVerificado: verificado);
      await tester.pumpWidget(
        ChangeNotifierProvider<FirebaseAuthService>.value(
          value: auth,
          child: const MaterialApp(
            home: Scaffold(body: VerificarCorreoBanner()),
          ),
        ),
      );
      return auth;
    }

    testWidgets('con el correo verificado no se dibuja', (final tester) async {
      await montar(tester, verificado: true);
      expect(find.text('Verifica tu correo'), findsNothing);
    });

    testWidgets('sin verificar avisa y reenvía', (final tester) async {
      final auth = await montar(tester, verificado: false);
      expect(find.text('Verifica tu correo'), findsOneWidget);

      await tester.tap(find.text('Reenviar correo'));
      await tester.pump();
      expect(auth.reenvios, 1);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('"Ya lo verifiqué" lo oculta cuando ya está verificado', (
      final tester,
    ) async {
      final auth = await montar(tester, verificado: false)
        ..verificaAlComprobar = true;

      await tester.tap(find.text('Ya lo verifiqué'));
      await tester.pump();

      expect(auth.correoVerificado, isTrue);
      expect(find.text('Verifica tu correo'), findsNothing);
    });
  });

  testWidgets('el chat ofrece "Reenviar correo" si falta verificar', (
    final tester,
  ) async {
    final auth = _AuthServicioFalso(correoVerificado: false);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FirebaseAuthService>.value(value: auth),
          ChangeNotifierProvider<AiProvider>.value(value: _AiSinVerificar()),
        ],
        child: const MaterialApp(home: Scaffold(body: IaTab())),
      ),
    );
    await tester.pump();

    expect(
      find.text('Verifica tu correo para usar el asistente.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reenviar correo'));
    await tester.pump();
    expect(auth.reenvios, 1);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
