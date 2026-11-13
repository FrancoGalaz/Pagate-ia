import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Inicio de sesión con Google.
///
/// - **Web**: `signInWithPopup(GoogleAuthProvider())`, funcional.
/// - **Móvil/escritorio**: requiere el paquete `google_sign_in`, todavía no
///   integrado. Las pantallas deben ocultar el botón cuando [isAvailable] es
///   `false`; [signIn] lanza [UnsupportedError] en ese caso.
class GoogleAuthService {
  final FirebaseAuth? _authOverride;

  GoogleAuthService({FirebaseAuth? auth}) : _authOverride = auth;

  /// Se resuelve de forma perezosa para que consultar [isAvailable] no
  /// requiera Firebase inicializado (widget tests, pantallas previas al login).
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// `true` solo en web por ahora.
  bool get isAvailable => kIsWeb;

  Future<UserCredential> signIn() async {
    if (!isAvailable) {
      throw UnsupportedError(
        'Google Sign-In en móvil requiere el paquete google_sign_in.',
      );
    }
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    return _auth.signInWithPopup(provider);
  }

  /// `true` si el usuario actual inició sesión con Google.
  bool get isGoogleUser {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'google.com');
  }
}
