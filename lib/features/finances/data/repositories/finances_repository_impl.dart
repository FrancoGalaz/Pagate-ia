import '../datasources/finances_firebase_datasource.dart';
import '../../domain/repositories/finances_repository.dart';
import '../../domain/entities/finances_summary_entity.dart';
import '../../domain/entities/finances_transaction_entity.dart';

class FinancesRepositoryImpl implements FinancesRepository {
  final FinancesFirebaseDataSource dataSource;

  FinancesRepositoryImpl({required this.dataSource});

  @override
  Future<List<FinancesSummaryEntity>> getAllMonths() {
    return dataSource.getAllMonths();
  }

  @override
  Future<FinancesSummaryEntity?> getMonth({
    required int year,
    required int month,
  }) {
    return dataSource.getMonth(year, month);
  }

  @override
  Future<void> addTransaction({
    required FinancesTransactionEntity transaction,
    required int year,
    required int month,
  }) {
    return dataSource.addTransaction(
      transaction: transaction,
      year: year,
      month: month,
    );
  }

  @override
  Future<void> updateTransaction({
    required FinancesTransactionEntity transaction,
  }) {
    return dataSource.updateTransaction(transaction: transaction);
  }

  @override
  Future<void> deleteTransaction({
    required String transactionId,
    required int year,
    required int month,
  }) {
    return dataSource.deleteTransaction(
      transactionId: transactionId,
      year: year,
      month: month,
    );
  }

  @override
  Future<List<FinancesTransactionEntity>> getTransactions({
    required int year,
    required int month,
  }) {
    return dataSource.getTransactions(year: year, month: month);
  }
}