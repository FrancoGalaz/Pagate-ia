import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/finances_summary_model.dart';
import '../models/finances_transaction_model.dart';
import '../../domain/entities/finances_summary_entity.dart';
import '../../domain/entities/finances_transaction_entity.dart';

/// Firebase data source for finances.
/// userId is injected at construction time for consistent scoping.
class FinancesFirebaseDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId;

  FinancesFirebaseDataSource({required String userId}) : _userId = userId;

  String _userSummariesPath() => 'finances/$_userId/summaries';
  String _userTransactionsPath() => 'finances/$_userId/transactions';
  String _summaryDocPath(int year, int month) =>
      '${_userSummariesPath()}/$year-$month';

  Future<List<FinancesSummaryEntity>> getAllMonths() async {
    final querySnapshot =
        await _firestore.collection(_userSummariesPath()).get();
    return querySnapshot.docs
        .map((doc) => FinancesSummaryModel.fromJson(
              doc.data() as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<FinancesSummaryEntity?> getMonth(int year, int month) async {
    final docSnapshot = await _firestore.doc(_summaryDocPath(year, month)).get();
    if (docSnapshot.exists) {
      return FinancesSummaryModel.fromJson(
        docSnapshot.data() as Map<String, dynamic>,
      );
    }
    return null;
  }

  Future<void> saveMonthSummary({
    required int year,
    required int month,
    required FinancesSummaryEntity summary,
  }) async {
    final summaryModel = FinancesSummaryModel.fromEntity(summary);
    await _firestore
        .doc(_summaryDocPath(year, month))
        .set(summaryModel.toJson());
  }

  Future<void> addTransaction({
    required FinancesTransactionEntity transaction,
    required int year,
    required int month,
  }) async {
    final transactionModel = FinancesTransactionModel.fromEntity(transaction);
    await _firestore
        .collection(_userTransactionsPath())
        .doc(transaction.id)
        .set(transactionModel.toJson());
  }

  Future<void> updateTransaction({
    required FinancesTransactionEntity transaction,
  }) async {
    final transactionModel = FinancesTransactionModel.fromEntity(transaction);
    await _firestore
        .collection(_userTransactionsPath())
        .doc(transaction.id)
        .update(transactionModel.toJson());
  }

  Future<void> deleteTransaction({
    required String transactionId,
    required int year,
    required int month,
  }) async {
    await _firestore
        .collection(_userTransactionsPath())
        .doc(transactionId)
        .delete();
  }

  Future<List<FinancesTransactionEntity>> getTransactions({
    required int year,
    required int month,
  }) async {
    final querySnapshot = await _firestore
        .collection(_userTransactionsPath())
        .where('date', isGreaterThanOrEqualTo: DateTime(year, month, 1))
        .where('date', isLessThan: DateTime(year, month + 1, 1))
        .get();

    return querySnapshot.docs
        .map((doc) => FinancesTransactionModel.fromJson(
              doc.data() as Map<String, dynamic>,
            ))
        .toList();
  }
}