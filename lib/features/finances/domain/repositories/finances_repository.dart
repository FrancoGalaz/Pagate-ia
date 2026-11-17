import '../entities/finances_summary_entity.dart';
import '../entities/finances_transaction_entity.dart';
import '../entities/fixed_expense_entity.dart';

/// Contrato de acceso a finanzas. Las lecturas son streams (tiempo real y
/// offline); los agregados mensuales los escribe solo el backend.
abstract class FinancesRepository {
  /// Resúmenes mensuales ordenados del más reciente al más antiguo.
  Stream<List<FinancesSummaryEntity>> watchMonths();

  /// Transacciones de un mes (`yyyy-MM`) ordenadas por fecha descendente.
  Stream<List<FinancesTransactionEntity>> watchTransactions(String monthKey);

  /// Gastos fijos recurrentes ordenados por nombre.
  Stream<List<FixedExpenseEntity>> watchFixedExpenses();

  /// Crea una transacción. El `id` de [transaction] se ignora.
  Future<void> addTransaction(FinancesTransactionEntity transaction);

  Future<void> updateTransaction(FinancesTransactionEntity transaction);

  Future<void> deleteTransaction(String transactionId);

  Future<void> addFixedExpense({required String name, required double amount});

  Future<void> deleteFixedExpense(String id);
}
