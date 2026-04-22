import '../entities/hourly_rate_entity.dart';

/// Use case for calculating and validating the hourly rate.
/// Following SOLID principles: Single Responsibility.
class CalculateHourlyRate {
  /// Executes the calculation logic.
  ///
  /// [desiredSalary] The amount the craftsman wants to earn monthly.
  /// [workingDays] Number of days the craftsman plans to work in a month.
  /// [hoursPerDay] Number of hours per day dedicated to work.
  HourlyRateEntity execute({
    required final double desiredSalary,
    required final int workingDays,
    required final double hoursPerDay,
  }) {
    final totalHours = workingDays * hoursPerDay;

    // Defensive programming: prevent division by zero or negative values.
    final safeTotalHours = totalHours > 0 ? totalHours : 1.0;

    return HourlyRateEntity(
      desiredMonthlySalary: desiredSalary,
      availableHoursPerMonth: safeTotalHours,
    );
  }
}
