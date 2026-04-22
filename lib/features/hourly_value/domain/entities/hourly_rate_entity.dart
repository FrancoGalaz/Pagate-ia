import 'package:equatable/equatable.dart';

/// Entity representing the hourly rate configuration for the user.
/// Follows the "Top 1%" standards: Immutable, Null-safe, and semantic.
class HourlyRateEntity extends Equatable {
  final double desiredMonthlySalary;
  final double availableHoursPerMonth;

  const HourlyRateEntity({
    required this.desiredMonthlySalary,
    required this.availableHoursPerMonth,
  }) : assert(availableHoursPerMonth > 0,
            'Available hours must be greater than zero');

  /// Calculates the hourly value based on the PRD formula.
  /// Valor Hora = Sueldo Deseado / Horas Disponibles.
  double get hourlyValue {
    if (availableHoursPerMonth <= 0) return 0.0;
    return desiredMonthlySalary / availableHoursPerMonth;
  }

  HourlyRateEntity copyWith({
    final double? desiredMonthlySalary,
    final double? availableHoursPerMonth,
  }) =>
      HourlyRateEntity(
        desiredMonthlySalary: desiredMonthlySalary ?? this.desiredMonthlySalary,
        availableHoursPerMonth:
            availableHoursPerMonth ?? this.availableHoursPerMonth,
      );

  @override
  List<Object?> get props => [desiredMonthlySalary, availableHoursPerMonth];
}
