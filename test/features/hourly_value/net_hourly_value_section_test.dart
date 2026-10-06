// PROPÓSITO
// ---------
// Que la PANTALLA diga la verdad, no solo el caso de uso. Lo que se vigila:
//
//   · Las dos cifras salen con su nombre exacto: "lo que te entró por hora"
//     (ingresos - comisiones) y "lo que te sobró por hora" (eso - gastos).
//   · La de arriba declara que NO descuenta los gastos. Ese era el fallo: la
//     pantalla enseñaba esa cifra rotulada como lo que había sobrado.
//   · Un mes en rojo se enseña en rojo, no recortado a cero.
//
// Sin Firebase: los dos providers se alimentan de repositorios falsos.

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
  final months = StreamController<List<FinancesSummaryEntity>>.broadcast();

  @override
  Stream<List<FinancesSummaryEntity>> watchMonths() => months.stream;

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

  Future<void> dispose() async {
    await transactions.close();
    await months.close();
  }
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

FinancesTransactionEntity _gasto(final double amount) =>
    FinancesTransactionEntity(
      id: 'gasto-$amount',
      title: 'Greda 25 kg',
      description: '',
      amount: amount,
      type: TransactionType.expense,
      date: DateTime.now(),
      category: 'Insumos y materiales',
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
    final List<FinancesTransactionEntity> movimientos, {
    final List<FinancesSummaryEntity> meses = const [],
  }) async {
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
    if (meses.isNotEmpty) financesRepository.months.add(meses);
    financesRepository.transactions.add(movimientos);
    await tester.pumpAndSettle();
  }

  testWidgets('separa lo que entró de lo que sobró, y lo rotula', (
    final tester,
  ) async {
    await montar(tester, [
      _ingreso(300000, platformFee: 20000),
      _gasto(100000),
    ]);

    // Entró: (300.000 - 20.000) / 100 = 2.800.
    expect(find.textContaining('LO QUE TE ENTRÓ POR HORA'), findsOneWidget);
    expect(find.text(r'$2.800'), findsOneWidget);
    // Sobró: 280.000 - 100.000 = 180.000, sobre 100 horas = 1.800.
    expect(find.textContaining('LO QUE TE SOBRÓ POR HORA'), findsOneWidget);
    expect(find.text(r'$1.800'), findsOneWidget);
  });

  testWidgets('la cifra de arriba declara que no descuenta los gastos', (
    final tester,
  ) async {
    await montar(tester, [
      _ingreso(300000, platformFee: 20000),
      _gasto(100000),
    ]);

    expect(find.textContaining('No descuenta tus gastos'), findsOneWidget);
    expect(find.textContaining(r'$20.000'), findsOneWidget);
    expect(find.textContaining('100 horas al mes'), findsOneWidget);
    // Y la de abajo dice de dónde sale su descuento.
    expect(find.textContaining(r'$100.000'), findsOneWidget);
  });

  testWidgets('sin comisión lo dice y sigue avisando de los gastos', (
    final tester,
  ) async {
    await montar(tester, [_ingreso(300000), _gasto(50000)]);

    expect(find.text(r'$3.000'), findsOneWidget);
    expect(find.text(r'$2.500'), findsOneWidget);
    expect(find.textContaining('No registraste comisiones'), findsOneWidget);
  });

  testWidgets('sin gastos lo declara en vez de repetir la cifra a secas', (
    final tester,
  ) async {
    await montar(tester, [_ingreso(300000, platformFee: 20000)]);

    expect(find.text(r'$2.800'), findsNWidgets(2));
    expect(find.textContaining('No registraste gastos'), findsOneWidget);
  });

  testWidgets('un mes en rojo se enseña en rojo, no en cero', (
    final tester,
  ) async {
    await montar(tester, [_ingreso(100000), _gasto(400000)]);

    // (100.000 - 400.000) / 100 = −3.000. El signo es U+2212.
    expect(find.text('−\$3.000'), findsOneWidget);
    expect(find.text(r'$1.000'), findsOneWidget);
  });

  testWidgets('sin ingresos no inventa una cifra', (final tester) async {
    await montar(tester, const []);

    expect(find.text(r'$0'), findsNothing);
    expect(
      find.textContaining('Registra tus ingresos del mes'),
      findsOneWidget,
    );
  });

  testWidgets('usa las comisiones del agregado del backend, no el recorrido', (
    final tester,
  ) async {
    // El agregado del mes dice 30.000 de comisiones; la lista visible solo
    // trae 1.000 porque la regla `list` la acota a 200 documentos. Manda el
    // agregado: 400.000 - 30.000 = 370.000, sobre 100 horas = 3.700.
    final mesActual = FinancesProvider.currentMonthKey;
    await montar(
      tester,
      [_ingreso(50000, platformFee: 1000)],
      meses: [
        FinancesSummaryEntity(
          monthKey: mesActual,
          totalIncome: 400000,
          totalExpenses: 100000,
          totalPlatformFees: 30000,
          hasPlatformFeesTotal: true,
          transactionCount: 250,
        ),
      ],
    );

    expect(find.text(r'$3.700'), findsOneWidget);
    expect(find.textContaining(r'$30.000'), findsOneWidget);
    // Sobró: 370.000 - 100.000 = 270.000, sobre 100 horas = 2.700.
    expect(find.text(r'$2.700'), findsOneWidget);
  });
}
