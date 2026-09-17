import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_bootstrap.dart';
import 'core/services/firebase_auth_service.dart';
import 'features/auth/presentation/pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase();
  runApp(const PagateIAApp());
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
