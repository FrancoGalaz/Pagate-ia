import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/ai_service.dart';
import '../../../dashboard/presentation/pages/dashboard_screen.dart';
import '../../../dashboard/presentation/providers/ai_provider.dart';
import '../../../finances/data/datasources/finances_firebase_datasource.dart';
import '../../../finances/data/repositories/finances_repository_impl.dart';
import '../../../finances/presentation/providers/finances_provider.dart';
import '../../../hourly_value/data/datasources/hourly_rate_local_datasource.dart';
import '../../../hourly_value/data/repositories/hourly_rate_repository_impl.dart';
import '../../../hourly_value/domain/usecases/calculate_hourly_rate.dart';
import '../../../hourly_value/presentation/bloc/hourly_rate_provider.dart';
import '../../../inventory/data/datasources/inventory_firebase_datasource.dart';
import '../../../inventory/data/repositories/inventory_repository_impl.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../onboarding/presentation/pages/setup_inicial_screen.dart';
import '../../../receipt_scan/presentation/widgets/receipt_share_listener.dart';
import '../../../user_profile/data/datasources/user_profile_firebase_datasource.dart';
import '../../../user_profile/data/repositories/user_profile_repository_impl.dart';
import '../../../user_profile/presentation/providers/user_profile_provider.dart';
import '../pages/splash_screen.dart';
import 'app_shell.dart';
import 'session_error_view.dart';
import 'cerrar_sesion.dart';

/// Alcance de un usuario autenticado.
///
/// Crea los providers con alcance de usuario (valor hora, inventario,
/// finanzas, perfil, IA) con `key: ValueKey(uid)`: al cambiar de usuario se
/// destruyen y se crean de nuevo. Debajo monta el `MaterialApp` de la sesión
/// (los providers quedan por encima del `Navigator`, así toda ruta apilada y
/// todo diálogo los ve) y [ProfileGate] decide entre onboarding y dashboard.
class UserScope extends StatelessWidget {
  const UserScope({super.key, required this.uid});

  final String uid;

  @override
  Widget build(final BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return MultiProvider(
      key: ValueKey('user-scope-$uid'),
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              createHourlyRateProvider(firestore: firestore, userId: uid),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              createInventoryProvider(firestore: firestore, userId: uid),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              createFinancesProvider(firestore: firestore, userId: uid),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              createUserProfileProvider(firestore: firestore, userId: uid),
        ),
        ChangeNotifierProvider(
          create: (_) => createAiProvider(firestore: firestore, userId: uid),
        ),
      ],
      // EL OYENTE DE "COMPARTIR A PÁGATE" VA DENTRO DEL `MaterialApp`, no
      // alrededor. `AppShell` ES el `MaterialApp`, así que un widget por
      // encima de él está por encima del Navigator y `Navigator.of` no
      // encontraría ninguno con el que abrir la pantalla de lectura. Aquí
      // ya tiene Navigator, y sigue por debajo del auth gate y dentro de
      // este `MultiProvider`, que es lo que exige: necesita el inventario
      // del usuario para emparejar y el perfil para saber si ya hay taller.
      child: AppShell(
        sessionKey: uid,
        home: const ReceiptShareListener(child: ProfileGate()),
      ),
    );
  }
}

/// Decide la pantalla raíz de la sesión según el perfil en `users/{uid}`.
class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});

  @override
  Widget build(final BuildContext context) {
    final profileProvider = context.watch<UserProfileProvider>();

    if (profileProvider.isLoading) return const SplashScreen();

    final error = profileProvider.error;
    if (error != null && profileProvider.profile == null) {
      return SessionErrorView(
        message: error,
        onRetry: profileProvider.retry,
        onSignOut: () => cerrarSesionConAviso(context),
      );
    }

    if (profileProvider.profile == null) return const SetupInicialScreen();

    return const DashboardScreen();
  }
}

// ─── Fábricas (firmas del contrato en docs/ARQUITECTURA.md) ─────────────────

HourlyRateProvider createHourlyRateProvider({
  required final FirebaseFirestore firestore,
  required final String userId,
}) => HourlyRateProvider(
  calculateUseCase: CalculateHourlyRate(),
  repository: HourlyRateRepositoryImpl(
    localDataSource: HourlyRateLocalDataSource(
      firestore: firestore,
      userId: userId,
    ),
  ),
);

InventoryProvider createInventoryProvider({
  required final FirebaseFirestore firestore,
  required final String userId,
}) => InventoryProvider(
  repository: InventoryRepositoryImpl(
    dataSource: InventoryFirebaseDataSource(
      firestore: firestore,
      userId: userId,
    ),
  ),
);

FinancesProvider createFinancesProvider({
  required final FirebaseFirestore firestore,
  required final String userId,
}) => FinancesProvider(
  repository: FinancesRepositoryImpl(
    dataSource: FinancesFirebaseDataSource(
      firestore: firestore,
      userId: userId,
    ),
  ),
);

UserProfileProvider createUserProfileProvider({
  required final FirebaseFirestore firestore,
  required final String userId,
}) => UserProfileProvider(
  repository: UserProfileRepositoryImpl(
    datasource: UserProfileFirebaseDatasource(
      firestore: firestore,
      userId: userId,
    ),
  ),
);

AiProvider createAiProvider({
  required final FirebaseFirestore firestore,
  required final String userId,
}) => AiProvider(service: AiService(), userId: userId, firestore: firestore);
