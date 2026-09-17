import '../../domain/entities/hourly_rate_entity.dart';

/// Modelo de persistencia del mapa `hourlyRate` en `users/{uid}`.
class HourlyRateModel extends HourlyRateEntity {
  const HourlyRateModel({
    required super.desiredMonthlySalary,
    required super.availableHoursPerMonth,
  });

  factory HourlyRateModel.fromJson(final Map<String, dynamic> json) =>
      HourlyRateModel(
        desiredMonthlySalary: (json['desiredMonthlySalary'] as num).toDouble(),
        availableHoursPerMonth:
            (json['availableHoursPerMonth'] as num).toDouble(),
      );

  /// Incluye `hourlyValue` (derivado) porque el backend lo lee para el
  /// contexto del chat, según el contrato.
  Map<String, dynamic> toJson() => {
        'desiredMonthlySalary': desiredMonthlySalary,
        'availableHoursPerMonth': availableHoursPerMonth,
        'hourlyValue': hourlyValue,
      };

  factory HourlyRateModel.fromEntity(final HourlyRateEntity entity) =>
      HourlyRateModel(
        desiredMonthlySalary: entity.desiredMonthlySalary,
        availableHoursPerMonth: entity.availableHoursPerMonth,
      );

  HourlyRateEntity toEntity() => HourlyRateEntity(
        desiredMonthlySalary: desiredMonthlySalary,
        availableHoursPerMonth: availableHoursPerMonth,
      );
}
