// PROPÓSITO
// ---------
// FIJAR EL SIGNIFICADO DE CADA CIFRA, que es lo que estaba roto.
//
// La pantalla enseñaba (ingresos - comisiones) / horas con el rótulo "Lo que
// te quedó por hora". Son dos cosas distintas:
//
//   · lo que ENTRÓ por hora  = (ingresos - comisiones) / horas
//   · lo que SOBRÓ por hora  = (ingresos - comisiones - gastos) / horas
//
// Medido con los datos demo de octubre de 2026 (980.000 de ingresos, 8.995 de
// comisiones, 640.500 de gastos, 120 horas) la pantalla decía 8.092 cuando lo
// que de verdad sobró por hora eran 2.754. Estos tests fijan las dos cifras
// por separado para que no se puedan volver a confundir.
//
// Y fijan de DÓNDE salen: del agregado mensual del backend, que no tiene tope,
// y no del recorrido de transacciones, que la regla `list` acota a 200
// documentos. El recorrido solo se usa si el agregado no trae la suma de
// comisiones (un mes escrito antes del contrato C-3).

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/hourly_value/domain/usecases/calculate_net_hourly_value.dart';

/// Resumen del mes como lo escribe el trigger `onTransactionWritten`.
FinancesSummaryEntity _mes({
  final double ingresos = 0,
  final double gastos = 0,
  final double comisiones = 0,
  final bool conComisiones = true,
  final int movimientos = 1,
}) => FinancesSummaryEntity(
      monthKey: '2026-10',
      totalIncome: ingresos,
      totalExpenses: gastos,
      totalPlatformFees: comisiones,
      hasPlatformFeesTotal: conComisiones,
      transactionCount: movimientos,
    );

FinancesTransactionEntity _ingreso({
  required final double amount,
  final double platformFee = 0,
  final String title = 'Venta en feria',
}) =>
    FinancesTransactionEntity(
      id: 'tx-$title-$amount',
      title: title,
      description: '',
      amount: amount,
      type: TransactionType.income,
      date: DateTime(2026, 10, 10),
      category: 'Venta en feria',
      platformFee: platformFee,
    );

FinancesTransactionEntity _gasto(final double amount) =>
    FinancesTransactionEntity(
      id: 'gasto-$amount',
      title: 'Greda 25 kg',
      description: '',
      amount: amount,
      type: TransactionType.expense,
      date: DateTime(2026, 10, 11),
      category: 'Insumos y materiales',
    );

void main() {
  const useCase = CalculateNetHourlyValue();

  group('Lo que te ENTRÓ por hora', () {
    test('son los ingresos menos las comisiones, sin tocar los gastos', () {
      // El caso demo real: 980.000 cobrados, 8.995 de comisiones, 640.500 de
      // gastos, 120 horas configuradas.
      final r = useCase.execute(
        summary: _mes(ingresos: 980000, gastos: 640500, comisiones: 8995),
        transactions: const [],
        availableHoursPerMonth: 120,
      );

      expect(r.entryIncome, 971005);
      expect(r.entryHourlyValue, closeTo(971005 / 120, 1e-9));
      // Lo que se vigila: los gastos NO entran en esta cifra.
      expect(r.entryHourlyValue, closeTo(8091.708, 0.001));
    });

    test('sin comisiones coincide con el bruto por hora', () {
      final r = useCase.execute(
        summary: _mes(ingresos: 600000, gastos: 100000),
        transactions: const [],
        availableHoursPerMonth: 160,
      );

      expect(r.hasPlatformFees, isFalse);
      expect(r.entryHourlyValue, 3750);
      expect(r.entryHourlyValue, r.grossHourlyValue);
    });

    test('con comisiones baja exactamente lo que se llevó la plataforma', () {
      // 22.800 es el 3,80% de 600.000: el 3,19% + IVA de Mercado Pago.
      final r = useCase.execute(
        summary: _mes(ingresos: 600000, comisiones: 22800),
        transactions: const [],
        availableHoursPerMonth: 160,
      );

      expect(r.grossHourlyValue, 3750);
      expect(r.entryHourlyValue, 3607.5);
      expect(
        r.grossHourlyValue - r.entryHourlyValue,
        closeTo(22800 / 160, 1e-9),
      );
    });

    test('una comisión absurda no produce un neto negativo', () {
      final r = useCase.execute(
        summary: _mes(ingresos: 50000, comisiones: 90000),
        transactions: const [],
        availableHoursPerMonth: 10,
      );

      expect(r.platformFees, 50000);
      expect(r.entryIncome, 0);
      expect(r.entryHourlyValue, 0);
    });
  });

  group('Lo que te SOBRÓ por hora', () {
    test('es lo que entró menos los gastos del mes', () {
      final r = useCase.execute(
        summary: _mes(ingresos: 980000, gastos: 640500, comisiones: 8995),
        transactions: const [],
        availableHoursPerMonth: 120,
      );

      expect(r.leftoverIncome, 330505);
      expect(r.leftoverHourlyValue, closeTo(2754.208, 0.001));
      // Las dos cifras son distintas y la de abajo es siempre la menor
      // cuando hay gastos.
      expect(r.leftoverHourlyValue, lessThan(r.entryHourlyValue));
    });

    test('sin gastos coincide con lo que entró, y lo declara', () {
      final r = useCase.execute(
        summary: _mes(ingresos: 300000, comisiones: 10000),
        transactions: const [],
        availableHoursPerMonth: 100,
      );

      expect(r.hasExpenses, isFalse);
      expect(r.leftoverHourlyValue, r.entryHourlyValue);
      expect(r.leftoverHourlyValue, 2900);
    });

    test('con más gastos que ingresos sale NEGATIVO y no se recorta', () {
      // Un mes en el que la artesana puso dinero de su bolsillo. Taparlo con
      // un 0 sería la misma mentira que este cambio vino a arreglar.
      final r = useCase.execute(
        summary: _mes(ingresos: 200000, gastos: 500000, comisiones: 0),
        transactions: const [],
        availableHoursPerMonth: 100,
      );

      expect(r.leftoverIncome, -300000);
      expect(r.leftoverHourlyValue, -3000);
      expect(r.entryHourlyValue, 2000);
    });
  });

  group('De dónde salen las comisiones', () {
    test('del agregado del backend, aunque haya transacciones a mano', () {
      // El agregado dice 8.995; la lista visible solo trae una comisión de
      // 1.000 porque está acotada a 200 documentos. Manda el agregado.
      final r = useCase.execute(
        summary: _mes(ingresos: 980000, comisiones: 8995),
        transactions: [_ingreso(amount: 50000, platformFee: 1000)],
        availableHoursPerMonth: 120,
      );

      expect(r.feesFromMonthlyAggregate, isTrue);
      expect(r.platformFees, 8995);
    });

    test('del recorrido SOLO si el agregado no trae la suma', () {
      // `hasPlatformFeesTotal: false` = mes escrito antes del contrato C-3.
      // Ahí un 0 no significa "no hubo comisiones" sino "no se sabe".
      final r = useCase.execute(
        summary: _mes(
          ingresos: 200000,
          gastos: 50000,
          conComisiones: false,
        ),
        transactions: [
          _ingreso(amount: 120000, platformFee: 4560),
          _ingreso(amount: 80000),
          _gasto(50000),
        ],
        availableHoursPerMonth: 100,
      );

      expect(r.feesFromMonthlyAggregate, isFalse);
      expect(r.platformFees, 4560);
      expect(r.entryIncome, 195440);
      expect(r.leftoverIncome, 145440);
    });

    test('el recorrido ignora los gastos: la comisión solo vive en ingresos',
        () {
      final r = useCase.execute(
        summary: _mes(ingresos: 300000, gastos: 85000, conComisiones: false),
        transactions: [
          _ingreso(amount: 300000, platformFee: 11400),
          _gasto(50000),
          _gasto(35000),
        ],
        availableHoursPerMonth: 150,
      );

      expect(r.platformFees, 11400);
      expect(r.entryHourlyValue, closeTo(288600 / 150, 1e-9));
      expect(r.leftoverHourlyValue, closeTo(203600 / 150, 1e-9));
    });
  });

  group('Casos de borde', () {
    test('sin ingresos no hay nada que mostrar y no se divide por cero', () {
      final r = useCase.execute(
        summary: _mes(gastos: 20000),
        transactions: const [],
        availableHoursPerMonth: 160,
      );

      expect(r.hasIncome, isFalse);
      expect(r.entryHourlyValue, 0);
      expect(r.entryHourlyValue.isNaN, isFalse);
    });

    test('con horas inválidas devuelve 0, no infinito', () {
      for (final horas in [0.0, -5.0, double.nan, double.infinity]) {
        final r = useCase.execute(
          summary: _mes(ingresos: 100000, gastos: 20000, comisiones: 1000),
          transactions: const [],
          availableHoursPerMonth: horas,
        );
        expect(r.entryHourlyValue, 0, reason: 'horas = $horas');
        expect(r.leftoverHourlyValue, 0, reason: 'horas = $horas');
        expect(r.entryHourlyValue.isFinite, isTrue);
      }
    });

    test('un agregado con cifras imposibles no contagia la pantalla', () {
      final r = useCase.execute(
        summary: _mes(
          ingresos: double.nan,
          gastos: double.infinity,
          comisiones: -100,
        ),
        transactions: const [],
        availableHoursPerMonth: 160,
      );

      expect(r.hasIncome, isFalse);
      expect(r.entryHourlyValue, 0);
      expect(r.leftoverHourlyValue, 0);
    });

    test('un mes vacío no lanza', () {
      final r = useCase.execute(
        summary: _mes(movimientos: 0),
        transactions: const [],
        availableHoursPerMonth: 160,
      );

      expect(r.hasIncome, isFalse);
      expect(r.grossIncome, 0);
      expect(r.platformFees, 0);
      expect(r.expenses, 0);
    });
  });
}
