import '../entities/hourly_rate_entity.dart';

/// Repository contract for HourlyRate data operations.
/// This abstraction allows the domain layer to remain independent of data sources.
abstract class HourlyRateRepository {
  /// Retrieves the current hourly rate configuration.
  /// Returns null if no configuration exists yet.
  Future<HourlyRateEntity?> getHourlyRate();

  /// Saves the hourly rate configuration.
  /// This operation must work offline (local persistence).
  Future<void> saveHourlyRate(final HourlyRateEntity hourlyRate);

  /// Checks if a configuration has been set.
  Future<bool> hasConfiguration();
}
