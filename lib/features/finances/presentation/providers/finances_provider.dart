import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/finances_summary_entity.dart';
import '../../domain/entities/finances_transaction_entity.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../../domain/repositories/finances_repository.dart';

/// Estado de finanzas alimentado por streams de Firestore.
///
/// - Se suscribe a meses y gastos fijos en el constructor, y a las
///   transacciones del mes seleccionado (la suscripción cambia al seleccionar
///   otro mes). Todo se cancela en [dispose].
/// - Los errores de lectura se exponen en [error] con un mensaje legible y se
///   pueden reintentar con [retry]. Los errores de escritura se propagan al
///   llamador para que la UI los muestre.
/// - La meta mensual vive en el perfil del usuario; la UI la inyecta con
///   [setMonthlyGoal].
class FinancesProvider extends ChangeNotifier {
  final FinancesRepository _repository;

  StreamSubscription<List<FinancesSummaryEntity>>? _monthsSub;
  StreamSubscription<List<FinancesTransactionEntity>>? _transactionsSub;
  StreamSubscription<List<FixedExpenseEntity>>? _fixedExpensesSub;

  List<FinancesSummaryEntity> _months = const [];
  List<FinancesTransactionEntity> _transactions = const [];
  List<FixedExpenseEntity> _fixedExpenses = const [];

  /// Mes elegido explícitamente por el usuario. `null` = automático (el más
  /// reciente con datos, o el mes actual si no hay ninguno).
  String? _selectedMonthKey;

  /// Mes al que está suscrita la lista de transacciones.
  String? _subscribedMonthKey;

  bool _monthsLoaded = false;
  bool _transactionsLoaded = false;
  String? _error;
  double _monthlyGoal = 0;
  bool _disposed = false;

  FinancesProvider({required FinancesRepository repository})
      : _repository = repository {
    _subscribeAll();
  }

  // ─── Estado de lectura ────────────────────────────────────────────

  List<FinancesSummaryEntity> get months => _months;

  /// Transacciones del mes seleccionado, de la más reciente a la más antigua.
  List<FinancesTransactionEntity> get transactions => _transactions;

  /// Alias de [transactions] para consumidores que solo necesitan
  /// "actividad reciente".
  List<FinancesTransactionEntity> get recentTransactions => _transactions;

  List<FixedExpenseEntity> get fixedExpenses => _fixedExpenses;

  double get totalFixedExpenses =>
      _fixedExpenses.fold(0, (final sum, final e) => sum + e.amount);

  /// Carga inicial de meses en curso (sin error).
  bool get isLoading => !_monthsLoaded && _error == null;

  /// La lista de transacciones del mes seleccionado aún no llegó.
  bool get isLoadingTransactions => !_transactionsLoaded && _error == null;

  /// Mensaje de error legible, o `null` si todo está bien.
  String? get error => _error;

  bool get hasData => _months.isNotEmpty || _transactions.isNotEmpty;

  double get monthlyGoal => _monthlyGoal;

  // ─── Selección de mes ─────────────────────────────────────────────

  static String get currentMonthKey => monthKeyFromDate(DateTime.now());

  /// Clave `yyyy-MM` del mes en pantalla.
  String get selectedMonthKey =>
      _selectedMonthKey ??
      (_months.isNotEmpty ? _months.first.monthKey : currentMonthKey);

  /// Índice del mes seleccionado dentro de [months]; 0 si no está en la lista.
  int get selectedIndex {
    final index = _months.indexWhere(
      (final m) => m.monthKey == selectedMonthKey,
    );
    return index < 0 ? 0 : index;
  }

  /// Resumen del mes seleccionado calculado por el backend, o `null` si el
  /// trigger todavía no lo creó.
  FinancesSummaryEntity? get selected {
    for (final m in _months) {
      if (m.monthKey == selectedMonthKey) return m;
    }
    return null;
  }

  /// Resumen del mes seleccionado, nunca nulo: si el backend aún no escribió
  /// el mes, se calcula localmente a partir de las transacciones visibles.
  FinancesSummaryEntity get summary {
    final fromBackend = selected;
    if (fromBackend != null) return fromBackend;
    double income = 0;
    double expenses = 0;
    for (final t in _transactions) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expenses += t.amount;
      }
    }
    return FinancesSummaryEntity(
      monthKey: selectedMonthKey,
      totalIncome: income,
      totalExpenses: expenses,
      transactionCount: _transactions.length,
    );
  }

  /// Progreso hacia la meta mensual del mes seleccionado (0..1).
  double get goalProgress => summary.goalProgress(_monthlyGoal);

  void selectMonth(final int index) {
    if (index < 0 || index >= _months.length) return;
    selectMonthKey(_months[index].monthKey);
  }

  void selectMonthKey(final String monthKey) {
    if (monthKey == selectedMonthKey && _selectedMonthKey != null) return;
    _selectedMonthKey = monthKey;
    _subscribeTransactions();
    notifyListeners();
  }

  /// Inyecta la meta mensual (vive en `users/{uid}.monthlyGoal`).
  void setMonthlyGoal(final double goal) {
    final safe = goal.isFinite && goal > 0 ? goal : 0.0;
    if (safe == _monthlyGoal) return;
    _monthlyGoal = safe;
    notifyListeners();
  }

  // ─── Escrituras ───────────────────────────────────────────────────

  /// Registra un ingreso o gasto. Lanza si el monto no es válido o si
  /// Firestore rechaza la escritura; la UI debe capturarlo y mostrarlo.
  ///
  /// Si el mes de la transacción no existe todavía en [months], no pasa nada:
  /// el trigger lo creará y el stream lo traerá. Mientras tanto la vista
  /// salta a ese mes para que el usuario vea lo que registró.
  Future<void> addTransaction({
    required final String title,
    required final double amount,
    required final TransactionType type,
    required final String category,
    required final DateTime date,
    final String description = '',
  }) async {
    final safeTitle = title.trim();
    if (safeTitle.isEmpty) {
      throw ArgumentError('El título no puede estar vacío');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('El monto debe ser mayor que cero');
    }
    final transaction = FinancesTransactionEntity(
      id: '',
      title: safeTitle,
      description: description.trim(),
      amount: amount,
      type: type,
      date: date,
      category: category.trim(),
    );
    await _repository.addTransaction(transaction);
    if (_disposed) return;
    if (transaction.monthKey != selectedMonthKey) {
      selectMonthKey(transaction.monthKey);
    }
  }

  Future<void> updateTransaction(
    final FinancesTransactionEntity transaction,
  ) =>
      _repository.updateTransaction(transaction);

  Future<void> deleteTransaction(final String id) =>
      _repository.deleteTransaction(id);

  Future<void> addFixedExpense({
    required final String name,
    required final double amount,
  }) async {
    final safeName = name.trim();
    if (safeName.isEmpty) {
      throw ArgumentError('El nombre no puede estar vacío');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('El monto debe ser mayor que cero');
    }
    await _repository.addFixedExpense(name: safeName, amount: amount);
  }

  Future<void> deleteFixedExpense(final String id) =>
      _repository.deleteFixedExpense(id);

  // ─── Reintento y ciclo de vida ────────────────────────────────────

  /// Cancela y vuelve a abrir todas las suscripciones.
  void retry() => _subscribeAll();

  void _subscribeAll() {
    _cancelAll();
    _error = null;
    _monthsLoaded = false;
    _monthsSub = _repository.watchMonths().listen(
          _onMonths,
          onError: _onStreamError,
        );
    _fixedExpensesSub = _repository.watchFixedExpenses().listen(
          _onFixedExpenses,
          onError: _onStreamError,
        );
    _subscribeTransactions(force: true);
    _notify();
  }

  void _subscribeTransactions({final bool force = false}) {
    final key = selectedMonthKey;
    if (!force && _transactionsSub != null && _subscribedMonthKey == key) {
      return;
    }
    _transactionsSub?.cancel();
    _subscribedMonthKey = key;
    _transactionsLoaded = false;
    _transactions = const [];
    _transactionsSub = _repository.watchTransactions(key).listen(
          _onTransactions,
          onError: _onStreamError,
        );
  }

  void _onMonths(final List<FinancesSummaryEntity> items) {
    _months = items;
    _monthsLoaded = true;
    // Si la selección es automática, el mes efectivo puede haber cambiado.
    _subscribeTransactions();
    _notify();
  }

  void _onTransactions(final List<FinancesTransactionEntity> items) {
    _transactions = items;
    _transactionsLoaded = true;
    _notify();
  }

  void _onFixedExpenses(final List<FixedExpenseEntity> items) {
    _fixedExpenses = items;
    _notify();
  }

  void _onStreamError(final Object error, final StackTrace stackTrace) {
    debugPrint('FinancesProvider: error en stream: $error\n$stackTrace');
    _error = describeError(error);
    _notify();
  }

  void _cancelAll() {
    _monthsSub?.cancel();
    _transactionsSub?.cancel();
    _fixedExpensesSub?.cancel();
    _monthsSub = null;
    _transactionsSub = null;
    _fixedExpensesSub = null;
    _subscribedMonthKey = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelAll();
    super.dispose();
  }

  /// Traduce una excepción a un mensaje corto en español.
  static String describeError(
    final Object error, {
    final String fallback = 'Error al cargar',
  }) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'No tienes permiso para ver estos datos';
        case 'unavailable':
          return 'Sin conexión';
        default:
          return fallback;
      }
    }
    if (error is ArgumentError) {
      return error.message?.toString() ?? fallback;
    }
    return fallback;
  }
}
