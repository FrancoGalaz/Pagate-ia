import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/firebase_auth_service.dart';

// Hourly Value
import 'features/hourly_value/domain/usecases/calculate_hourly_rate.dart';
import 'features/hourly_value/data/datasources/hourly_rate_local_datasource.dart';
import 'features/hourly_value/data/repositories/hourly_rate_repository_impl.dart';
import 'features/hourly_value/presentation/bloc/hourly_rate_provider.dart';

// Inventory
import 'features/inventory/data/datasources/inventory_firebase_datasource.dart';
import 'features/inventory/data/repositories/inventory_repository_impl.dart';
import 'features/inventory/presentation/providers/inventory_provider.dart';

// Finances
import 'features/finances/data/datasources/finances_firebase_datasource.dart';
import 'features/finances/data/repositories/finances_repository_impl.dart';
import 'features/finances/presentation/providers/finances_provider.dart';

// User Profile
import 'features/user_profile/data/datasources/user_profile_firebase_datasource.dart';
import 'features/user_profile/data/repositories/user_profile_repository_impl.dart';
import 'features/user_profile/presentation/providers/user_profile_provider.dart';

// Auth
import 'features/auth/presentation/pages/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PagateIAApp());
}

/// Factory for creating HourlyRateProvider with a given userId.
HourlyRateProvider _createHourlyRateProvider(String userId) {
  final calculateUseCase = CalculateHourlyRate();
  final dataSource = HourlyRateLocalDataSource(
    firestore: FirebaseFirestore.instance,
    userId: userId,
  );
  return HourlyRateProvider(
    calculateUseCase: calculateUseCase,
    repository: HourlyRateRepositoryImpl(localDataSource: dataSource),
  );
}

/// Factory for creating InventoryProvider with a given userId.
InventoryProvider _createInventoryProvider(String userId) {
  final dataSource = InventoryFirebaseDataSource(
    firestore: FirebaseFirestore.instance,
    userId: userId,
  );
  return InventoryProvider(
    repository: InventoryRepositoryImpl(dataSource: dataSource),
  );
}

/// Factory for creating FinancesProvider with a given userId.
FinancesProvider _createFinancesProvider(String userId) {
  final dataSource = FinancesFirebaseDataSource(userId: userId);
  return FinancesProvider(
    repository: FinancesRepositoryImpl(dataSource: dataSource),
  );
}

/// Factory for creating UserProfileProvider with a given userId.
UserProfileProvider _createUserProfileProvider(String userId) {
  final dataSource = UserProfileFirebaseDatasource(userId: userId);
  return UserProfileProvider(
    repository: UserProfileRepositoryImpl(datasource: dataSource),
  );
}

class PagateIAApp extends StatelessWidget {
  const PagateIAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth service - listens to FirebaseAuth state changes
        ChangeNotifierProvider(
          create: (_) => FirebaseAuthService(),
        ),

        // Hourly Rate - recreated when auth changes
        ChangeNotifierProxyProvider<FirebaseAuthService, HourlyRateProvider>(
          create: (_) => _createHourlyRateProvider('anonymous'),
          update: (_, auth, previous) =>
              _createHourlyRateProvider(auth.userId),
        ),

        // Inventory - recreated when auth changes
        ChangeNotifierProxyProvider<FirebaseAuthService, InventoryProvider>(
          create: (_) => _createInventoryProvider('anonymous'),
          update: (_, auth, previous) => _createInventoryProvider(auth.userId),
        ),

        // Finances - recreated when auth changes
        ChangeNotifierProxyProvider<FirebaseAuthService, FinancesProvider>(
          create: (_) => _createFinancesProvider('anonymous'),
          update: (_, auth, previous) => _createFinancesProvider(auth.userId),
        ),

        // User Profile - recreated when auth changes
        ChangeNotifierProxyProvider<FirebaseAuthService, UserProfileProvider>(
          create: (_) => _createUserProfileProvider('anonymous'),
          update: (_, auth, previous) =>
              _createUserProfileProvider(auth.userId),
        ),
      ],
      child: MaterialApp(
        title: 'Págate-IA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const LoginScreen(),
      ),
    );
  }
}