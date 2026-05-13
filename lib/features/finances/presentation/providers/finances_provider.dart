import 'package:flutter/foundation.dart';
import '../../domain/repositories/finances_repository.dart';
import '../../domain/entities/finances_summary_entity.dart';
import '../../domain/entities/finances_transaction_entity.dart';

class FinancesProvider extends ChangeNotifier {
  final FinancesRepository _repository;

  List<FinancesSummaryEntity> _months = [];
  List<FinancesTransactionEntity> _recentTransactions = [];
  int _selectedIndex = 0;
  bool _isLoading = false;

  FinancesProvider({required FinancesRepository repository})
      : _repository = repository {
    _load();
  }

  List<FinancesSummaryEntity> get months => _months;
  List<FinancesTransactionEntity> get recentTransactions =>
      _recentTransactions;
  int get selectedIndex => _selectedIndex;
  FinancesSummaryEntity? get selected =>
      _months.isEmpty ? null : _months[_selectedIndex];
  bool get isLoading => _isLoading;
  bool get hasData => _months.isNotEmpty;

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
    _months = await _repository.getAllMonths();
    // Load recent transactions for the latest month
    if (_months.isNotEmpty) {
      await _loadRecentTransactions();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final now = DateTime.now();
      _recentTransactions = await _repository.getTransactions(
        year: now.year,
        month: now.month,
      );
    } catch (_) {
      _recentTransactions = [];
    }
  }

  void selectMonth(int index) {
    if (index < 0 || index >= _months.length) return;
    _selectedIndex = index;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _load();
  }
}