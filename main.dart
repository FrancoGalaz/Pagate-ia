import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/hourly_value/domain/usecases/calculate_hourly_rate.dart';
import 'features/hourly_value/data/repositories/mock_hourly_rate_repository.dart';
import 'features/hourly_value/presentation/bloc/hourly_rate_provider.dart';
import 'features/inventory/data/repositories/mock_inventory_repository.dart';
import 'features/inventory/presentation/providers/inventory_provider.dart';
import 'features/finances/data/repositories/mock_finances_repository.dart';
import 'features/finances/presentation/providers/finances_provider.dart';
import 'features/user_profile/data/repositories/mock_user_profile_repository.dart';
import 'features/user_profile/presentation/providers/user_profile_provider.dart';
import 'features/auth/presentation/pages/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PagateIAApp());
}

class PagateIAApp extends StatelessWidget {
  const PagateIAApp({super.key});

  @override
  Widget build(final BuildContext context) {
    final calculateUseCase = CalculateHourlyRate();
    final dataSource = MockHourlyRateDataSource();
    final hourlyRepo = MockHourlyRateRepository(dataSource: dataSource);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (final _) => HourlyRateProvider(
            calculateUseCase: calculateUseCase,
            repository: hourlyRepo,
          ),
        ),
        ChangeNotifierProvider(
          create: (final _) => InventoryProvider(
            repository: MockInventoryRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (final _) => FinancesProvider(
            repository: MockFinancesRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (final _) => UserProfileProvider(
            repository: MockUserProfileRepository(),
          ),
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
