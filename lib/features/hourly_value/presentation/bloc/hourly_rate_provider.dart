import 'package:flutter/foundation.dart';
import '../../domain/entities/hourly_rate_entity.dart';
import '../../domain/usecases/calculate_hourly_rate.dart';
import '../../domain/repositories/hourly_rate_repository.dart';

/// State management for Hourly Rate configuration
/// Using ChangeNotifier for reactive UI updates
class HourlyRateProvider extends ChangeNotifier {
  final CalculateHourlyRate _calculateUseCase;
  final HourlyRateRepository _repository;

  HourlyRateEntity? _currentRate;
  bool _isLoading = false;
  String? _errorMessage;

  HourlyRateProvider({
    required final CalculateHourlyRate calculateUseCase,
    required final HourlyRateRepository repository,
  })  : _calculateUseCase = calculateUseCase,
        _repository = repository {
    _loadSavedRate();
  }

  // Getters
  HourlyRateEntity? get currentRate => _currentRate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasConfiguration => _currentRate != null;

  /// Load saved hourly rate from repository
  Future<void> _loadSavedRate() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentRate = await _repository.getHourlyRate();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error al cargar configuración: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculate and save hourly rate
  Future<bool> calculateAndSave({
    required final double desiredSalary,
    required final int workingDays,
    required final double hoursPerDay,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Calculate using the use case
      final calculatedRate = _calculateUseCase.execute(
        desiredSalary: desiredSalary,
        workingDays: workingDays,
        hoursPerDay: hoursPerDay,
      );

      // Save to repository
      await _repository.saveHourlyRate(calculatedRate);

      // Update local state
      _currentRate = calculatedRate;
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar configuración: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh configuration from repository
  Future<void> refresh() async {
    await _loadSavedRate();
  }
}
