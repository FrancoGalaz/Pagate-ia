import '../../domain/entities/finances_summary_entity.dart';
import '../../domain/entities/finances_transaction_entity.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../../domain/repositories/finances_repository.dart';
import '../datasources/finances_firebase_datasource.dart';

class FinancesRepositoryImpl implements FinancesRepository {
  final FinancesFirebaseDataSource dataSource;

  FinancesRepositoryImpl({required this.dataSource});

  @override
  Stream<List<FinancesSummaryEntity>> watchMonths() => dataSource.watchMonths();

  @override
  Stream<List<FinancesTransactionEntity>> watchTransactions(
    final String monthKey,
  ) =>
      dataSource.watchTransactions(monthKey);

  @override
  Stream<List<FixedExpenseEntity>> watchFixedExpenses() =>
      dataSource.watchFixedExpenses();

  @override
  Future<void> addTransaction(final FinancesTransactionEntity transaction) =>
      dataSource.addTransaction(transaction);

  @override
  Future<void> updateTransaction(
    final FinancesTransactionEntity transaction,
  ) =>
      dataSource.updateTransaction(transaction);

  @override
  Future<void> deleteTransaction(final String transactionId) =>
      dataSource.deleteTransaction(transactionId);

  @override
  Future<void> addFixedExpense({
    required final String name,
    required final double amount,
  }) =>
      dataSource.addFixedExpense(name: name, amount: amount);

  @override
  Future<void> deleteFixedExpense(final String id) =>
      dataSource.deleteFixedExpense(id);
}
