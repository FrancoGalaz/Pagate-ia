import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/finances_summary_entity.dart';
import '../../domain/entities/finances_transaction_entity.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../models/finances_summary_model.dart';
import '../models/finances_transaction_model.dart';
import '../models/fixed_expense_model.dart';

/// Acceso a Firestore para finanzas bajo `users/{uid}/...`.
///
/// - `transactions`: lectura/escritura del cliente.
/// - `fixedExpenses`: lectura/escritura del cliente.
/// - `months`: SOLO lectura; los escribe el trigger `onTransactionWritten`.
class FinancesFirebaseDataSource {
  final FirebaseFirestore _firestore;
  final String _userId;

  FinancesFirebaseDataSource({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  DocumentReference<Map<String, dynamic>> get _user =>
      _firestore.collection('users').doc(_userId);

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _user.collection('transactions');

  CollectionReference<Map<String, dynamic>> get _months =>
      _user.collection('months');

  CollectionReference<Map<String, dynamic>> get _fixedExpenses =>
      _user.collection('fixedExpenses');

  // ─── Lecturas (streams) ───────────────────────────────────────────

  /// Transacciones del mes `yyyy-MM`, ordenadas por fecha descendente.
  ///
  /// Se filtra por `monthKey` (mismo criterio que usa el trigger para los
  /// totales) y se ordena en memoria para no depender de un índice compuesto
  /// `monthKey + date`.
  Stream<List<FinancesTransactionEntity>> watchTransactions(
    final String monthKey,
  ) => _transactions.where('monthKey', isEqualTo: monthKey).snapshots().map((
    final snapshot,
  ) {
    final items = snapshot.docs
        .map(
          (final doc) => FinancesTransactionModel.fromDoc(doc.id, doc.data()),
        )
        .toList();
    items.sort((final a, final b) => b.date.compareTo(a.date));
    return items;
  });

  /// Resúmenes mensuales del más reciente al más antiguo. Firestore no admite
  /// ordenar por id de documento en forma descendente, así que se pide
  /// ascendente (`yyyy-MM` ordena cronológicamente) y se invierte en memoria.
  Stream<List<FinancesSummaryEntity>> watchMonths() => _months
      .orderBy(FieldPath.documentId)
      .snapshots()
      .map(
        (final snapshot) => snapshot.docs.reversed
            .map(
              (final doc) => FinancesSummaryModel.fromDoc(doc.id, doc.data()),
            )
            .toList(),
      );

  /// Gastos fijos ordenados por nombre.
  Stream<List<FixedExpenseEntity>> watchFixedExpenses() => _fixedExpenses
      .orderBy('name')
      .snapshots()
      .map(
        (final snapshot) => snapshot.docs
            .map((final doc) => FixedExpenseModel.fromDoc(doc.id, doc.data()))
            .toList(),
      );

  // ─── Escrituras ───────────────────────────────────────────────────

  /// Crea una transacción con id generado por Firestore. El `id` de la
  /// entidad se ignora.
  Future<void> addTransaction(
    final FinancesTransactionEntity transaction,
  ) async {
    final model = FinancesTransactionModel.fromEntity(transaction);
    await _transactions.add({
      ...model.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTransaction(
    final FinancesTransactionEntity transaction,
  ) async {
    final model = FinancesTransactionModel.fromEntity(transaction);
    await _transactions.doc(transaction.id).update({
      ...model.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTransaction(final String transactionId) =>
      _transactions.doc(transactionId).delete();

  Future<void> addFixedExpense({
    required final String name,
    required final double amount,
  }) async {
    final model = FixedExpenseModel(id: '', name: name, amount: amount);
    await _fixedExpenses.add({
      ...model.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteFixedExpense(final String id) =>
      _fixedExpenses.doc(id).delete();
}
