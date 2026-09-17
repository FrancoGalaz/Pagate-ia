import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Envuelve [FirebaseAuth] y expone el usuario actual de forma reactiva.
///
/// Escucha `userChanges()` (sesión + cambios de perfil como `displayName`)
/// para notificar a la UI; el gate de autenticación usa [authStateChanges],
/// que solo emite al iniciar o cerrar sesión.
class FirebaseAuthService extends ChangeNotifier {
  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;
  User? _user;

  FirebaseAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance {
    _user = _auth.currentUser;
    _subscription = _auth.userChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  /// Emite al iniciar o cerrar sesión. Es la fuente de verdad del `AuthGate`.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get user => _user;
  bool get isAuthenticated => _user != null;

  /// `null` cuando no hay sesión. Ya no existe el usuario `'anonymous'`.
  String? get userId => _user?.uid;
  String? get email => _user?.email;
  String? get displayName => _user?.displayName;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  /// Crea la cuenta y, si se indica, guarda [displayName] en el perfil de
  /// Auth para que el onboarding pueda precargar el nombre.
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await credential.user?.updateDisplayName(name);
    }
    return credential;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset({required String email}) =>
      _auth.sendPasswordResetEmail(email: email);

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
