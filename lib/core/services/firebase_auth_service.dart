import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

/// Envuelve [FirebaseAuth] y expone el usuario actual de forma reactiva.
///
/// Escucha `userChanges()` (sesión + cambios de perfil como `displayName`)
/// para notificar a la UI; el gate de autenticación usa [authStateChanges],
/// que solo emite al iniciar o cerrar sesión.
class FirebaseAuthService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore? _firestoreInyectado;
  late final StreamSubscription<User?> _subscription;
  User? _user;
  bool _cerrandoSesion = false;

  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestoreInyectado = firestore {
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

  /// `false` hasta que la persona abre el enlace del correo de verificación.
  /// `chat` y `scanReceipt` lo exigen; el resto de la app funciona igual.
  bool get correoVerificado => _user?.emailVerified ?? false;

  /// `true` desde que empieza [cerrarSesion] hasta el próximo inicio de
  /// sesión. Mientras dura, el `AuthGate` no monta el `UserScope` aunque su
  /// stream todavía traiga al usuario anterior.
  ///
  /// Se baja al iniciar sesión o registrarse, y no al recibir el evento de
  /// `signOut`: el orden entre ese evento y el del `AuthGate` no está
  /// garantizado, y bajarlo antes remontaría un instante la sesión cerrada.
  bool get cerrandoSesion => _cerrandoSesion;

  /// Cuánto se espera a que Firestore confirme las escrituras pendientes
  /// antes de avisar que se perderán.
  static const esperaEscriturasPendientes = Duration(seconds: 5);

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    _cerrandoSesion = false;
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Crea la cuenta y, si se indica, guarda [displayName] en el perfil de
  /// Auth para que el onboarding pueda precargar el nombre.
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _cerrandoSesion = false;
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await credential.user?.updateDisplayName(name);
    }
    // Si el envío falla, la cuenta queda creada igual: el aviso de Inicio
    // ofrece reenviarlo.
    try {
      await credential.user?.sendEmailVerification();
    } catch (e) {
      debugPrint('[Auth] No se pudo enviar el correo de verificación: $e');
    }
    return credential;
  }

  /// Vuelve a enviar el correo de verificación.
  Future<void> reenviarVerificacion() async =>
      _auth.currentUser?.sendEmailVerification();

  /// Recarga el usuario y fuerza un token nuevo, que es el que lleva
  /// `email_verified` al backend. Devuelve si el correo ya está verificado.
  Future<bool> comprobarVerificacion() async {
    final actual = _auth.currentUser;
    if (actual == null) return false;
    await actual.reload();
    final recargado = _auth.currentUser;
    if (recargado?.emailVerified ?? false) {
      await recargado!.getIdToken(true);
    }
    _user = recargado;
    notifyListeners();
    return correoVerificado;
  }

  /// Cierra la sesión y borra la caché offline de Firestore del usuario.
  ///
  /// Orden:
  /// 1. Si se pasa [confirmarPerdidaDeCambios] y Firestore no confirma las
  ///    escrituras pendientes en [esperaEscriturasPendientes], se pregunta.
  ///    Si la respuesta es `false`, no se cierra nada y devuelve `false`.
  ///    Tras `deleteAccount` no se pasa: esas escrituras ya no tienen dueño.
  /// 2. [cerrandoSesion] pasa a `true` y se espera un frame: el `AuthGate`
  ///    desmonta el `UserScope` y sus providers cancelan los streams.
  /// 3. `terminate` → `clearPersistence`. No hace falta volver a fijar los
  ///    `Settings`: los guarda el lado Dart y el plugin de Android se los
  ///    aplica a la instancia nueva (`getFirestoreFromPigeon`).
  /// 4. `signOut`, siempre, aunque falle el paso 3.
  Future<bool> cerrarSesion({
    Future<bool> Function()? confirmarPerdidaDeCambios,
  }) async {
    final firestore = _firestoreInyectado ?? FirebaseFirestore.instance;

    if (confirmarPerdidaDeCambios != null) {
      final sincronizado = await firestore
          .waitForPendingWrites()
          .then((_) => true, onError: (final Object _) => false)
          .timeout(esperaEscriturasPendientes, onTimeout: () => false);
      if (!sincronizado && !await confirmarPerdidaDeCambios()) return false;
    }

    _cerrandoSesion = true;
    notifyListeners();
    await WidgetsBinding.instance.endOfFrame;

    try {
      await firestore.terminate();
      await firestore.clearPersistence();
    } catch (e) {
      debugPrint('[Sesión] No se pudo borrar la caché de Firestore: $e');
    } finally {
      await _auth.signOut();
    }
    return true;
  }

  Future<void> sendPasswordReset({required String email}) =>
      _auth.sendPasswordResetEmail(email: email);

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
