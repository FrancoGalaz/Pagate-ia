// PROPÓSITO
// ---------
// Revisión prelanzamiento 2.2. `monthKey` decide en qué mes cuenta un
// movimiento. Se derivaba de la hora local del teléfono, así que el mismo
// instante caía en meses distintos según la zona horaria, y editar un
// movimiento desde otra zona lo cambiaba de mes.
//
// Dos reglas:
//   1. `monthKeyFromDate` usa siempre la hora de Chile continental
//      (America/Santiago), esté donde esté el teléfono.
//   2. Un movimiento ya guardado conserva su `monthKey` mientras no cambie su
//      fecha.
//
// Las fechas van en UTC para que el test dé lo mismo en cualquier máquina.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/finances/data/models/finances_transaction_model.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';

void main() {
  group('monthKeyFromDate · siempre en hora de Chile', () {
    test('verano (UTC-3): el mes cambia a las 03:00 UTC', () {
      expect(monthKeyFromDate(DateTime.utc(2026, 11, 1, 2, 59)), '2026-10');
      expect(monthKeyFromDate(DateTime.utc(2026, 11, 1, 3)), '2026-11');
    });

    test('invierno (UTC-4): el mes cambia a las 04:00 UTC', () {
      expect(monthKeyFromDate(DateTime.utc(2026, 7, 1, 3, 59)), '2026-06');
      expect(monthKeyFromDate(DateTime.utc(2026, 7, 1, 4)), '2026-07');
    });

    test('el 1 de abril todavía es horario de verano', () {
      // El cambio a invierno es el domingo 5 de abril de 2026.
      expect(monthKeyFromDate(DateTime.utc(2026, 4, 1, 2, 59)), '2026-03');
      expect(monthKeyFromDate(DateTime.utc(2026, 4, 1, 3)), '2026-04');
    });

    test('el 1 de septiembre todavía es horario de invierno', () {
      // El cambio a verano es el domingo 6 de septiembre de 2026.
      expect(monthKeyFromDate(DateTime.utc(2026, 9, 1, 3, 59)), '2026-08');
      expect(monthKeyFromDate(DateTime.utc(2026, 9, 1, 4)), '2026-09');
    });

    test('el cambio de año cae en el año de Chile', () {
      expect(monthKeyFromDate(DateTime.utc(2027, 1, 1, 2)), '2026-12');
    });

    test('da lo mismo con el mismo instante en hora local', () {
      final instante = DateTime.utc(2026, 11, 1, 2, 59);
      expect(monthKeyFromDate(instante.toLocal()), '2026-10');
    });
  });

  group('un movimiento guardado conserva su monthKey', () {
    // Guardado como octubre, aunque su instante en Chile ya es noviembre: es
    // lo que deja un teléfono que lo anotó en otra zona horaria.
    final fecha = DateTime.utc(2026, 11, 1, 3, 30);
    Map<String, dynamic> doc() => {
          'title': 'Venta en feria',
          'amount': 120000,
          'type': 'income',
          'category': 'Venta en feria',
          'date': Timestamp.fromDate(fecha),
          'monthKey': '2026-10',
        };

    test('al leerlo y volver a guardarlo sin tocar la fecha, no cambia', () {
      final model = FinancesTransactionModel.fromDoc('tx1', doc());

      expect(model.monthKey, '2026-10');
      expect(model.toFirestore(forUpdate: true)['monthKey'], '2026-10');
    });

    test('editar otro campo no lo cambia de mes', () {
      final editado = FinancesTransactionModel.fromDoc('tx1', doc())
          .copyWith(title: 'Venta en feria (corregido)');

      expect(
        FinancesTransactionModel.fromEntity(editado)
            .toFirestore(forUpdate: true)['monthKey'],
        '2026-10',
      );
    });

    test('cambiar la fecha sí lo recalcula', () {
      final editado = FinancesTransactionModel.fromDoc('tx1', doc())
          .copyWith(date: DateTime.utc(2026, 12, 15, 15));

      expect(editado.monthKey, '2026-12');
    });

    test('un monthKey guardado que no es un mes se ignora', () {
      final model = FinancesTransactionModel.fromDoc(
        'tx1',
        {...doc(), 'monthKey': '2026-13'},
      );

      expect(model.monthKey, '2026-11');
    });
  });
}
