import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/config/firebase_errors.dart';
import '../../domain/entities/hourly_rate_entity.dart';
import '../../domain/repositories/hourly_rate_repository.dart';
import '../../domain/usecases/calculate_hourly_rate.dart';

/// Estado del valor hora, alimentado por el stream de `users/{uid}`.
///
/// - [isLoading]: aún no llegó el primer snapshot.
/// - [error]: fallo de lectura; [retry] vuelve a suscribirse.
/// - [saveError]: último fallo al guardar, visible hasta el próximo intento.
class HourlyRateProvider extends ChangeNotifier {
  final CalculateHourlyRate _calculateUseCase;
  final HourlyRateRepository _repository;

  StreamSubscription<HourlyRateEntity?>? _subscription;
  HourlyRateEntity? _currentRate;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String? _saveError;

  HourlyRateProvider({
    required final CalculateHourlyRate calculateUseCase,
    required final HourlyRateRepository repository,
  })  : _calculateUseCase = calculateUseCase,
        _repository = repository {
    _subscribe();
  }

  HourlyRateEntity? get currentRate => _currentRate;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get saveError => _saveError;
  bool get hasConfiguration => _currentRate != null;

  void _subscribe() {
    _subscription?.cancel();
    _isLoading = true;
    _error = null;
    _subscription = _repository.watchHourlyRate().listen(
      (final rate) {
        _currentRate = rate;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (final Object e) {
        _isLoading = false;
        _error = describeFirebaseError(e);
        notifyListeners();
      },
    );
  }

  void retry() {
    _subscribe();
    notifyListeners();
  }

  /// Calcula y guarda el valor hora a partir del par que de verdad se
  /// persiste: sueldo al mes y horas al mes. Devuelve `true` si se guardó; si
  /// falla, deja el motivo en [saveError].
  Future<bool> saveMonthlyHours({
    required final double desiredSalary,
    required final double availableHoursPerMonth,
  }) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      final rate = _calculateUseCase.fromMonthlyHours(
        desiredSalary: desiredSalary,
        availableHoursPerMonth: availableHoursPerMonth,
      );
      await _repository.saveHourlyRate(rate);
      _currentRate = rate;
      return true;
    } catch (e) {
      _saveError = describeFirebaseError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearSaveError() {
    _saveError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
