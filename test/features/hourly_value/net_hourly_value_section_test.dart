// PROPÓSITO
// ---------
// Que la pantalla diga la verdad, no solo el caso de uso: con comisiones
// registradas muestra el valor hora YA descontado y lo declara en una linea;
// sin comisiones muestra la cifra completa y tambien lo dice. Sin Firebase:
// los dos providers se alimentan de repositorios falsos.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/fixed_expense_entity.dart';
import 'package:pagate_ia/features/finances/domain/repositories/finances_repository.dart';
import 'package:pagate_ia/features/finances/presentation/providers/finances_provider.dart';
import 'package:pagate_ia/features/hourly_value/domain/entities/hourly_rate_entity.dart';
import 'package:pagate_ia/features/hourly_value/domain/repositories/hourly_rate_repository.dart';
import 'package:pagate_ia/features/hourly_value/domain/usecases/calculate_hourly_rate.dart';
import 'package:pagate_ia/features/hourly_value/presentation/bloc/hourly_rate_provider.dart';
import 'package:pagate_ia/features/hourly_value/presentation/widgets/net_hourly_value_section.dart';

class FakeHourlyRateRepository implements HourlyRateRepository {
  FakeHourlyRateRepository(this.rate);

  final HourlyRateEntity? rate;

  @override
  Stream<HourlyRateEntity?> watchHourlyRate() => Stream.value(rate);

  @override
  Future<HourlyRateEntity?> getHourlyRate() async => rate;

  @override
  Future<void> saveHourlyRate(final HourlyRateEntity hourlyRate) async {}

  @override
  Future<bool> hasConfiguration() async => rate != null;
}

class FakeFinancesRepository implements FinancesRepository {
  final transactions =
      StreamController<List<FinancesTransactionEntity>>.broadcast();

  @override
  Stream<List<FinancesSummaryEntity>> watchMonths() => const Stream.empty();

  @override
  Stream<List<FinancesTransactionEntity>> watchTransactions(
    final String monthKey,
  ) =>
      transactions.stream;

  @override
  Stream<List<FixedExpenseEntity>> watchFixedExpenses() =>
      const Stream.empty();

  @override
  Future<void> addTransaction(
    final FinancesTransactionEntity transaction,
  ) async {}

  @override
  Future<void> updateTransaction(
    final FinancesTransactionEntity transaction,
  ) async {}

  @override
  Future<void> deleteTransaction(final String transactionId) async {}

  @override
  Future<void> addFixedExpense({
    required final String name,
    required final double amount,
  }) async {}

  @override
  Future<void> deleteFixedExpense(final String id) async {}

  Future<void> dispose() => transactions.close();
}

FinancesTransactionEntity _ingreso(
  final double amount, {
  final double platformFee = 0,
}) =>
    FinancesTransactionEntity(
      id: 'tx-$amount-$platformFee',
      title: 'Venta por Instagram',
      description: '',
      amount: amount,
      type: TransactionType.income,
      date: DateTime.now(),
      category: 'Venta por Instagram',
      platformFee: platformFee,
    );

void main() {
  late FakeFinancesRepository financesRepository;
  late FinancesProvider finances;
  late HourlyRateProvider hourly;

  setUp(() {
    financesRepository = FakeFinancesRepository();
    finances = FinancesProvider(repository: financesRepository);
    hourly = HourlyRateProvider(
      calculateUseCase: CalculateHourlyRate(),
      // 100 horas al mes para que las cifras del test sean exactas.
      repository: FakeHourlyRateRepository(
        const HourlyRateEntity(
          desiredMonthlySalary: 500000,
          availableHoursPerMonth: 100,
        ),
      ),
    );
  });

  tearDown(() async {
    finances.dispose();
    hourly.dispose();
    await financesRepository.dispose();
  });

  Future<void> montar(
    final WidgetTester tester,
    final List<FinancesTransactionEntity> movimientos,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<FinancesProvider>.value(value: finances),
            ChangeNotifierProvider<HourlyRateProvider>.value(value: hourly),
          ],
          child: const Scaffold(
            body: SingleChildScrollView(child: NetHourlyValueSection()),
          ),
        ),
      ),
    );
    financesRepository.transactions.add(movimientos);
    await tester.pumpAndSettle();
  }

  testWidgets('con comision muestra el valor hora ya descontado y lo dice', (
    final tester,
  ) async {
    await montar(tester, [_ingreso(300000, platformFee: 20000)]);

    // 300.000 - 20.000 = 280.000, sobre 100 horas.
    expect(find.text(r'$2.800'), findsOneWidget);
    expect(find.textContaining('Ya descuenta'), findsOneWidget);
    expect(find.textContaining(r'$20.000'), findsOneWidget);
    expect(find.textContaining('100 horas al mes'), findsOneWidget);
  });

  testWidgets('sin comision muestra la cifra completa y tambien lo dice', (
    final tester,
  ) async {
    await montar(tester, [_ingreso(300000)]);

    expect(find.text(r'$3.000'), findsOneWidget);
    expect(find.textContaining('No registraste comisiones'), findsOneWidget);
    expect(find.textContaining('Ya descuenta'), findsNothing);
  });

  testWidgets('sin ingresos no inventa una cifra', (final tester) async {
    await montar(tester, const []);

    expect(find.text(r'$0'), findsNothing);
    expect(
      find.textContaining('Registra tus ingresos del mes'),
      findsOneWidget,
    );
  });
}
