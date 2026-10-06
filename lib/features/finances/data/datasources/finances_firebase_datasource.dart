import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_limits.dart';
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
  ///
  /// El `.limit()` es OBLIGATORIO: sin él `request.query.limit` llega nulo a
  /// `firestore.rules`, la regla `list` deniega la consulta entera y la
  /// pantalla de Finanzas se queda vacía (ver [FirestoreLimits]). No es una
  /// optimización de lecturas: es la diferencia entre ver los movimientos y
  /// no ver nada.
  Stream<List<FinancesTransactionEntity>> watchTransactions(
    final String monthKey,
  ) => _transactions
      .where('monthKey', isEqualTo: monthKey)
      .limit(FirestoreLimits.maxList)
      .snapshots()
      .map((final snapshot) {
        final items = snapshot.docs
            .map(
              (final doc) =>
                  FinancesTransactionModel.fromDoc(doc.id, doc.data()),
            )
            .toList();
        items.sort((final a, final b) => b.date.compareTo(a.date));
        return items;
      });

  /// Resúmenes mensuales del más reciente al más antiguo. Firestore no admite
  /// ordenar por id de documento en forma descendente, así que se pide
  /// ascendente (`yyyy-MM` ordena cronológicamente) y se invierte en memoria.
  ///
  /// El `.limit()` lo exige la regla `list` (ver [FirestoreLimits]), y aquí
  /// tiene que ser `limit` y NO `limitToLast`, aunque lo que interesa sean los
  /// meses recientes: `limitToLast` invierte el orden de la consulta que viaja
  /// al servidor, y un orden descendente por id de documento está prohibido.
  /// Comprobado contra el emulador: la consulta vuelve con
  /// `FAILED_PRECONDITION: Firestore does not support descending key scans`.
  /// El coste de usar `limit` ascendente es que, pasados 200 meses de
  /// historial (16 años y 8 meses), el tope se quedaría con los más
  /// antiguos; cuando eso sea un problema real hay que paginar, no subir el
  /// tope, porque 200 es el techo de la regla.
  Stream<List<FinancesSummaryEntity>> watchMonths() => _months
      .orderBy(FieldPath.documentId)
      .limit(FirestoreLimits.maxList)
      .snapshots()
      .map(
        (final snapshot) => snapshot.docs.reversed
            .map(
              (final doc) => FinancesSummaryModel.fromDoc(doc.id, doc.data()),
            )
            .toList(),
      );

  /// Gastos fijos ordenados por nombre. El `.limit()` lo exige la regla
  /// `list`; sin él la sección de gastos fijos se ve vacía (ver
  /// [FirestoreLimits]).
  Stream<List<FixedExpenseEntity>> watchFixedExpenses() => _fixedExpenses
      .orderBy('name')
      .limit(FirestoreLimits.maxList)
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
