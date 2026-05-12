import '../entities/finances_summary_entity.dart';
import '../entities/finances_transaction_entity.dart';

abstract class FinancesRepository {
  Future<List<FinancesSummaryEntity>> getAllMonths();
  Future<FinancesSummaryEntity?> getMonth({required int year, required int month});
  Future<void> addTransaction({required FinancesTransactionEntity transaction, required int year, required int month});
  Future<void> updateTransaction({required FinancesTransactionEntity transaction});
  Future<void> deleteTransaction({required String transactionId, required int year, required int month});
  Future<List<FinancesTransactionEntity>> getTransactions({required int year, required int month});
}