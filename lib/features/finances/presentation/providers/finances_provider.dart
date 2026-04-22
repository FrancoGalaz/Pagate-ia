import 'package:flutter/foundation.dart';
import '../../data/repositories/mock_finances_repository.dart';
import '../../domain/entities/finances_summary_entity.dart';

class FinancesProvider extends ChangeNotifier {
  final MockFinancesRepository _repository;

  List<FinancesSummaryEntity> _months = [];
  int _selectedIndex = 0;
  bool _isLoading = false;

  FinancesProvider({required final MockFinancesRepository repository})
      : _repository = repository {
    _load();
  }

  List<FinancesSummaryEntity> get months => _months;
  int get selectedIndex => _selectedIndex;
  FinancesSummaryEntity? get selected =>
      _months.isEmpty ? null : _months[_selectedIndex];
  bool get isLoading => _isLoading;

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
    _months = await _repository.getAllMonths();
    _isLoading = false;
    notifyListeners();
  }

  void selectMonth(final int index) {
    if (index < 0 || index >= _months.length) return;
    _selectedIndex = index;
    notifyListeners();
  }
}
