import '../../domain/entities/hourly_rate_entity.dart';

/// Data model for HourlyRate with JSON serialization.
/// This model extends the domain entity to add persistence capabilities.
class HourlyRateModel extends HourlyRateEntity {
  const HourlyRateModel({
    required super.desiredMonthlySalary,
    required super.availableHoursPerMonth,
  });

  /// Creates a model from JSON data.
  factory HourlyRateModel.fromJson(final Map<String, dynamic> json) => HourlyRateModel(
      desiredMonthlySalary: (json['desiredMonthlySalary'] as num).toDouble(),
      availableHoursPerMonth:
          (json['availableHoursPerMonth'] as num).toDouble(),
    );

  /// Converts the model to JSON for persistence.
  Map<String, dynamic> toJson() => {
      'desiredMonthlySalary': desiredMonthlySalary,
      'availableHoursPerMonth': availableHoursPerMonth,
    };

  /// Creates a model from a domain entity.
  factory HourlyRateModel.fromEntity(final HourlyRateEntity entity) => HourlyRateModel(
      desiredMonthlySalary: entity.desiredMonthlySalary,
      availableHoursPerMonth: entity.availableHoursPerMonth,
    );

  /// Converts this model to a domain entity.
  HourlyRateEntity toEntity() => HourlyRateEntity(
      desiredMonthlySalary: desiredMonthlySalary,
      availableHoursPerMonth: availableHoursPerMonth,
    );
}
