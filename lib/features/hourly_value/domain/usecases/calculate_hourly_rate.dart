import '../entities/hourly_rate_entity.dart';

/// Calcula y valida el valor hora objetivo: sueldo deseado ÷ horas del mes.
///
/// Lo que se PERSISTE es el par (sueldo, horas al mes): `hourlyRate` en
/// `users/{uid}` solo acepta `desiredMonthlySalary`, `availableHoursPerMonth`
/// y el derivado `hourlyValue` (`firestore.rules`, `validHourlyRate`). Por eso
/// [fromMonthlyHours] es la entrada principal y [execute] —días × horas al
/// día— es una comodidad de cálculo construida encima: el desglose no se
/// guarda en ninguna parte.
class CalculateHourlyRate {
  /// Entrada principal: el sueldo que se quiere al mes y las horas que se
  /// trabajan al mes, que es exactamente lo que se guarda.
  ///
  /// Si [availableHoursPerMonth] no es utilizable (0, negativo, NaN) se usa
  /// 1 hora como mínimo defensivo, para no dividir por cero ni devolver una
  /// entidad imposible de construir.
  HourlyRateEntity fromMonthlyHours({
    required final double desiredSalary,
    required final double availableHoursPerMonth,
  }) {
    final safeHours =
        availableHoursPerMonth.isFinite && availableHoursPerMonth > 0
            ? availableHoursPerMonth
            : 1.0;

    return HourlyRateEntity(
      desiredMonthlySalary: desiredSalary,
      availableHoursPerMonth: safeHours,
    );
  }

  /// Variante por desglose: [workingDays] × [hoursPerDay] son las horas del
  /// mes. El desglose NO se persiste; solo su producto.
  HourlyRateEntity execute({
    required final double desiredSalary,
    required final int workingDays,
    required final double hoursPerDay,
  }) =>
      fromMonthlyHours(
        desiredSalary: desiredSalary,
        availableHoursPerMonth: workingDays * hoursPerDay,
      );
}
