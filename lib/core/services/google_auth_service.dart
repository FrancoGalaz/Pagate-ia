import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for Google Sign-In across platforms.
///
/// - **Web**: Uses `signInWithPopup(GoogleAuthProvider())`
/// - **Mobile**: Would use the `google_sign_in` package (not yet implemented)
class GoogleAuthService {
  final FirebaseAuth _auth;

  GoogleAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  /// Returns true if Google Sign-In is available on this platform.
  bool get isAvailable => kIsWeb;

  /// Signs in with Google using the platform-appropriate method.
  ///
  /// On web, opens a popup for Google account selection.
  /// On mobile, this requires the `google_sign_in` package.
  Future<UserCredential> signIn() async {
    if (kIsWeb) {
      // Web: use Firebase Auth popup
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      return await _auth.signInWithPopup(provider);
    }

    // Mobile: would need google_sign_in package
    // For now, throw a helpful error
    throw UnsupportedError(
      'Google Sign-In in mobile requires the google_sign_in package. '
      'Add it to pubspec.yaml and use GoogleSignIn().signIn() instead.',
    );
  }

  /// Returns true if the current user was authenticated via Google.
  bool get isGoogleUser {
    final user = _auth.currentUser;
    if (user == null) return false;
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return true;
    }
    return false;
  }
}
