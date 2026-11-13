import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/hourly_value/domain/entities/hourly_rate_entity.dart';
import 'package:pagate_ia/features/hourly_value/domain/usecases/calculate_hourly_rate.dart';

void main() {
  late CalculateHourlyRate useCase;

  setUp(() {
    useCase = CalculateHourlyRate();
  });

  group('CalculateHourlyRate', () {
    test('calcula el valor hora con sueldo, dias y horas normales', () {
      final result = useCase.execute(
        desiredSalary: 800000,
        workingDays: 20,
        hoursPerDay: 8,
      );

      expect(result.desiredMonthlySalary, 800000);
      expect(result.availableHoursPerMonth, 160);
      expect(result.hourlyValue, 5000);
    });

    test('con cero horas no divide por cero ni lanza', () {
      final sinDias = useCase.execute(
        desiredSalary: 500000,
        workingDays: 0,
        hoursPerDay: 8,
      );
      final sinHoras = useCase.execute(
        desiredSalary: 500000,
        workingDays: 20,
        hoursPerDay: 0,
      );

      for (final result in [sinDias, sinHoras]) {
        expect(result.availableHoursPerMonth, greaterThan(0));
        expect(result.hourlyValue.isFinite, isTrue);
        expect(result.hourlyValue.isNaN, isFalse);
      }
      // Con horas invalidas el caso de uso usa 1 hora como minimo defensivo.
      expect(sinDias.availableHoursPerMonth, 1.0);
      expect(sinDias.hourlyValue, 500000);
    });

    test('acepta valores decimales y mantiene precision', () {
      final result = useCase.execute(
        desiredSalary: 1234567.89,
        workingDays: 22,
        hoursPerDay: 7.5,
      );

      expect(result.availableHoursPerMonth, closeTo(165.0, 1e-9));
      expect(result.hourlyValue, closeTo(1234567.89 / 165.0, 1e-6));
    });

    test('devuelve una entidad comparable por valor', () {
      final a = useCase.execute(
        desiredSalary: 100,
        workingDays: 10,
        hoursPerDay: 1,
      );
      final b = useCase.execute(
        desiredSalary: 100,
        workingDays: 5,
        hoursPerDay: 2,
      );

      expect(a, equals(b));
      expect(
        a,
        const HourlyRateEntity(
          desiredMonthlySalary: 100,
          availableHoursPerMonth: 10,
        ),
      );
    });
  });
}
