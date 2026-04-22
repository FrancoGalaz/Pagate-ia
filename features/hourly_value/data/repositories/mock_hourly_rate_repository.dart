import '../../domain/entities/hourly_rate_entity.dart';
import '../../domain/repositories/hourly_rate_repository.dart';

/// Mock data source for demo purposes (without Firebase)
/// Stores data in memory only
class MockHourlyRateDataSource {
  HourlyRateEntity? _savedRate;

  Future<HourlyRateEntity?> getHourlyRate() async {
    await Future.delayed(
        const Duration(milliseconds: 300)); // Simulate network delay
    return _savedRate;
  }

  Future<void> saveHourlyRate(final HourlyRateEntity rate) async {
    await Future.delayed(
        const Duration(milliseconds: 300)); // Simulate network delay
    _savedRate = rate;
  }

  Future<bool> hasConfiguration() async => _savedRate != null;
}

/// Mock repository implementation for demo
class MockHourlyRateRepository implements HourlyRateRepository {
  final MockHourlyRateDataSource _dataSource;

  MockHourlyRateRepository({required final MockHourlyRateDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<HourlyRateEntity?> getHourlyRate() async => _dataSource.getHourlyRate();

  @override
  Future<void> saveHourlyRate(final HourlyRateEntity hourlyRate) async {
    await _dataSource.saveHourlyRate(hourlyRate);
  }

  @override
  Future<bool> hasConfiguration() async => _dataSource.hasConfiguration();
}
