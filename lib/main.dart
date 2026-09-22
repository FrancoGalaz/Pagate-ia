import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_bootstrap.dart';
import 'core/services/firebase_auth_service.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/auth/presentation/widgets/bootstrap_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _boot();
}

/// Arranque con red de seguridad: si `bootstrapFirebase()` falla, en lugar de
/// dejar la pantalla negra se monta [BootstrapErrorApp] con un botón de
/// reintento que vuelve a ejecutar este mismo flujo.
Future<void> _boot() async {
  try {
    await bootstrapFirebase();
    runApp(const PagateIAApp());
  } catch (e, st) {
    debugPrint('[Bootstrap] No se pudo iniciar Firebase: $e\n$st');
    runApp(BootstrapErrorApp(error: e, onRetry: () => unawaited(_boot())));
  }
}

/// Raíz de la app. Solo provee [FirebaseAuthService]; todo lo demás depende
/// del usuario y lo crea `UserScope` debajo de [AuthGate].
class PagateIAApp extends StatelessWidget {
  const PagateIAApp({super.key});

  @override
  Widget build(final BuildContext context) => ChangeNotifierProvider(
        create: (_) => FirebaseAuthService(),
        child: const AuthGate(),
      );
}
