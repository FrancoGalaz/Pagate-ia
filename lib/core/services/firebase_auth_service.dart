import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

/// Service that wraps FirebaseAuth and provides reactive auth state.
/// Exposes currentUserId for use by datasources and repositories.
class FirebaseAuthService extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  auth.User? _user;

  FirebaseAuthService() {
    _auth.authStateChanges().listen((auth.User? user) {
      _user = user;
      notifyListeners();
    });
  }

  auth.User? get user => _user;
  bool get isAuthenticated => _user != null;
  String get userId => _user?.uid ?? 'anonymous';
  String get email => _user?.email ?? '';

  Future<auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential;
  }

  Future<auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
