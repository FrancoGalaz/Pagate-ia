// PROPÓSITO
// ---------
// El valor hora neto es el nucleo del producto, y antes del contrato C-3 la
// app no descontaba las comisiones del medio de pago. Estos tests fijan las
// dos mitades del contrato: con comision registrada el valor hora BAJA
// exactamente lo que se llevo la plataforma, y sin comision el resultado es
// el mismo de siempre.

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/hourly_value/domain/usecases/calculate_net_hourly_value.dart';

FinancesTransactionEntity _ingreso({
  required final double amount,
  final double platformFee = 0,
  final TransactionDocType docType = TransactionDocType.sinDocumento,
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
      docType: docType,
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

  group('CalculateNetHourlyValue · sin comisiones', () {
    test('el neto es igual al bruto: nada cambia para quien cobra en efectivo',
        () {
      final result = useCase.execute(
        transactions: [_ingreso(amount: 400000), _ingreso(amount: 200000)],
        availableHoursPerMonth: 160,
      );

      expect(result.grossIncome, 600000);
      expect(result.platformFees, 0);
      expect(result.netIncome, 600000);
      expect(result.netHourlyValue, 3750);
      expect(result.netHourlyValue, result.grossHourlyValue);
      expect(result.hasPlatformFees, isFalse);
      expect(result.incomeCount, 2);
    });
  });

  group('CalculateNetHourlyValue · con comisiones', () {
    test('el valor hora baja exactamente lo que se llevo la plataforma', () {
      // 600.000 cobrados, 22.800 de comision (3,80% de 600.000, que es el
      // 3,19% + IVA de Mercado Pago sobre una venta de ese monto).
      final result = useCase.execute(
        transactions: [
          _ingreso(
            amount: 400000,
            platformFee: 15200,
            docType: TransactionDocType.boletaVenta,
          ),
          _ingreso(amount: 200000, platformFee: 7600),
        ],
        availableHoursPerMonth: 160,
      );

      expect(result.grossIncome, 600000);
      expect(result.platformFees, 22800);
      expect(result.netIncome, 577200);
      expect(result.hasPlatformFees, isTrue);
      expect(result.grossHourlyValue, 3750);
      expect(result.netHourlyValue, 3607.5);
      // Lo que se mide: la cifra que se muestra es MENOR que la de antes.
      expect(result.netHourlyValue, lessThan(result.grossHourlyValue));
      expect(
        result.grossHourlyValue - result.netHourlyValue,
        closeTo(22800 / 160, 1e-9),
      );
    });

    test('una comision solo en un ingreso tambien descuenta', () {
      final result = useCase.execute(
        transactions: [
          _ingreso(amount: 120000, platformFee: 4560),
          _ingreso(amount: 80000),
        ],
        availableHoursPerMonth: 100,
      );

      expect(result.platformFees, 4560);
      expect(result.netIncome, 195440);
      expect(result.netHourlyValue, 1954.4);
    });

    test('una comision absurda no produce un neto negativo', () {
      final result = useCase.execute(
        transactions: [_ingreso(amount: 50000, platformFee: 90000)],
        availableHoursPerMonth: 10,
      );

      // La entidad acota la comision al monto, asi que el neto es 0 y no
      // una cifra negativa imposible.
      expect(result.platformFees, 50000);
      expect(result.netIncome, 0);
      expect(result.netHourlyValue, 0);
    });
  });

  group('CalculateNetHourlyValue · casos de borde', () {
    test('los gastos no entran en el calculo', () {
      final result = useCase.execute(
        transactions: [
          _ingreso(amount: 300000, platformFee: 11400),
          _gasto(50000),
          _gasto(35000),
        ],
        availableHoursPerMonth: 150,
      );

      expect(result.incomeCount, 1);
      expect(result.grossIncome, 300000);
      expect(result.platformFees, 11400);
      expect(result.netHourlyValue, closeTo(288600 / 150, 1e-9));
    });

    test('sin ingresos no hay nada que mostrar y no se divide por cero', () {
      final result = useCase.execute(
        transactions: [_gasto(20000)],
        availableHoursPerMonth: 160,
      );

      expect(result.hasIncome, isFalse);
      expect(result.netHourlyValue, 0);
      expect(result.netHourlyValue.isNaN, isFalse);
    });

    test('con horas invalidas devuelve 0, no infinito', () {
      for (final horas in [0.0, -5.0, double.nan, double.infinity]) {
        final result = useCase.execute(
          transactions: [_ingreso(amount: 100000, platformFee: 1000)],
          availableHoursPerMonth: horas,
        );
        expect(result.netHourlyValue, 0, reason: 'horas = $horas');
        expect(result.netHourlyValue.isFinite, isTrue);
      }
    });

    test('una lista vacia no lanza', () {
      final result = useCase.execute(
        transactions: const [],
        availableHoursPerMonth: 160,
      );

      expect(result.hasIncome, isFalse);
      expect(result.grossIncome, 0);
      expect(result.platformFees, 0);
    });
  });
}
