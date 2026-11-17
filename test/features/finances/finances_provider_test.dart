// Test de FinancesProvider contra el contrato de docs/ARQUITECTURA.md.
//
// NOTA PARA EL COORDINADOR: FakeFinancesRepository sigue la interfaz
// FinancesRepository y FinancesSummaryEntity tal como quedaron en lib/ al
// escribir este test. El provider se está migrando en paralelo; este test
// asume que expone `months`, `selected`, `selectedIndex`, `selectMonth`,
// `isLoading`, `error` (String?) y `retry()`, y que se suscribe a
// `watchTransactions(selected.monthKey)` al cambiar de mes. Si las firmas
// difieren, ajustar solo los @override del fake, el helper _summary() y esos
// getters.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/fixed_expense_entity.dart';
import 'package:pagate_ia/features/finances/domain/repositories/finances_repository.dart';
import 'package:pagate_ia/features/finances/presentation/providers/finances_provider.dart';

/// Repositorio falso controlado desde el test.
class FakeFinancesRepository implements FinancesRepository {
  final monthsController =
      StreamController<List<FinancesSummaryEntity>>.broadcast();
  final transactionsController =
      StreamController<List<FinancesTransactionEntity>>.broadcast();
  final fixedExpensesController =
      StreamController<List<FixedExpenseEntity>>.broadcast();

  /// monthKeys pedidos a watchTransactions, en orden.
  final List<String> requestedMonthKeys = [];
  int watchMonthsSubscriptions = 0;
  final List<FinancesTransactionEntity> added = [];
  final List<String> deleted = [];

  @override
  Stream<List<FinancesSummaryEntity>> watchMonths() {
    watchMonthsSubscriptions++;
    return monthsController.stream;
  }

  @override
  Stream<List<FinancesTransactionEntity>> watchTransactions(
    final String monthKey,
  ) {
    requestedMonthKeys.add(monthKey);
    return transactionsController.stream;
  }

  @override
  Stream<List<FixedExpenseEntity>> watchFixedExpenses() =>
      fixedExpensesController.stream;

  @override
  Future<void> addTransaction(
    final FinancesTransactionEntity transaction,
  ) async {
    added.add(transaction);
  }

  @override
  Future<void> updateTransaction(
    final FinancesTransactionEntity transaction,
  ) async {}

  @override
  Future<void> deleteTransaction(final String transactionId) async {
    deleted.add(transactionId);
  }

  @override
  Future<void> addFixedExpense({
    required final String name,
    required final double amount,
  }) async {}

  @override
  Future<void> deleteFixedExpense(final String id) async {}

  Future<void> dispose() async {
    await monthsController.close();
    await transactionsController.close();
    await fixedExpensesController.close();
  }
}

FinancesSummaryEntity _summary(
  final String monthKey, {
  final double income = 100000,
  final double expenses = 40000,
}) => FinancesSummaryEntity(
  monthKey: monthKey,
  totalIncome: income,
  totalExpenses: expenses,
  transactionCount: 3,
);

void main() {
  late FakeFinancesRepository repository;
  late FinancesProvider provider;

  setUp(() {
    repository = FakeFinancesRepository();
    provider = FinancesProvider(repository: repository);
  });

  tearDown(() async {
    provider.dispose();
    await repository.dispose();
  });

  group('FinancesProvider', () {
    test('expone los meses que entrega el stream', () async {
      expect(provider.isLoading, isTrue);
      expect(provider.months, isEmpty);

      repository.monthsController.add([
        _summary('2026-09'),
        _summary('2026-08', income: 50000),
      ]);
      await pumpEventQueue();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.months, hasLength(2));
      expect(provider.months.first.monthKey, '2026-09');
      expect(provider.selected?.monthKey, '2026-09');
      expect(repository.watchMonthsSubscriptions, 1);
    });

    test('cambia de mes y escucha las transacciones de ese mes', () async {
      repository.monthsController.add([
        _summary('2026-09'),
        _summary('2026-08'),
      ]);
      await pumpEventQueue();

      var notified = 0;
      provider.addListener(() => notified++);

      provider.selectMonth(1);
      await pumpEventQueue();

      expect(provider.selectedIndex, 1);
      expect(provider.selected?.monthKey, '2026-08');
      expect(repository.requestedMonthKeys.last, '2026-08');
      expect(notified, greaterThan(0));

      // Indices fuera de rango se ignoran.
      provider.selectMonth(5);
      expect(provider.selectedIndex, 1);
    });

    test('muestra error cuando el stream falla y permite reintentar', () async {
      repository.monthsController.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await pumpEventQueue();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.error, contains('No tienes permiso'));

      provider.retry();
      await pumpEventQueue();

      expect(repository.watchMonthsSubscriptions, 2);

      repository.monthsController.add([_summary('2026-09')]);
      await pumpEventQueue();

      expect(provider.error, isNull);
      expect(provider.months, hasLength(1));
    });
  });
}
