import '../entities/hourly_rate_entity.dart';

/// Contrato de acceso al valor hora.
abstract class HourlyRateRepository {
  /// Valor hora en tiempo real; `null` si aún no se configuró.
  Stream<HourlyRateEntity?> watchHourlyRate();

  Future<void> saveHourlyRate(final HourlyRateEntity hourlyRate);
}
