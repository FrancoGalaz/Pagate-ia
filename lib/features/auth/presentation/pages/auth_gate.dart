import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firebase_auth_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/session_error_view.dart';
import '../widgets/user_scope.dart';
import 'splash_screen.dart';
import 'welcome_screen.dart';

/// Raíz reactiva de la app: escucha `authStateChanges` y decide qué sesión
/// mostrar.
///
/// - Esperando el primer evento → splash.
/// - Sin usuario → [WelcomeScreen] (de ahí se llega a login / registro).
/// - Cerrando sesión ([FirebaseAuthService.cerrandoSesion]) → splash, sin
///   [UserScope]: así sus providers sueltan Firestore antes de borrar la caché.
/// - Con usuario → [UserScope] con `key: ValueKey(uid)`, que crea los
///   providers del usuario y decide entre onboarding y dashboard.
///
/// Cada rama monta su propio `MaterialApp` (ver [AppShell]) con una `key` de
/// sesión distinta, así el `Navigator` se reinicia al cambiar de usuario y las
/// pantallas de login/registro no necesitan navegar manualmente al terminar.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _authState;

  @override
  void initState() {
    super.initState();
    _authState = context.read<FirebaseAuthService>().authStateChanges;
  }

  void _retry() {
    setState(() {
      _authState = context.read<FirebaseAuthService>().authStateChanges;
    });
  }

  @override
  Widget build(final BuildContext context) => StreamBuilder<User?>(
        stream: _authState,
        builder: (final context, final snapshot) {
          if (snapshot.hasError) {
            debugPrint('[AuthGate] Error de sesión: ${snapshot.error}');
            return AppShell(
              sessionKey: 'auth-error',
              home: SessionErrorView(
                message: 'No pudimos comprobar tu sesión. Revisa tu conexión '
                    'e inténtalo de nuevo.',
                detail: snapshot.error,
                onRetry: _retry,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppShell(sessionKey: 'boot', home: SplashScreen());
          }
          final user = snapshot.data;
          if (user == null) {
            return const AppShell(
              sessionKey: 'signed-out',
              home: WelcomeScreen(),
            );
          }
          if (context.watch<FirebaseAuthService>().cerrandoSesion) {
            return const AppShell(
              sessionKey: 'signing-out',
              home: SplashScreen(),
            );
          }
          return UserScope(key: ValueKey(user.uid), uid: user.uid);
        },
      );
}
