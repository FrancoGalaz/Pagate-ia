// PROPÓSITO
// ---------
// Serialización de ida y vuelta de un movimiento, con los dos campos del
// contrato C-3 (`docType`, `platformFee`). Lo que se protege aquí es que un
// documento escrito ANTES del contrato siga funcionando: los dos campos son
// opcionales y su ausencia tiene que significar exactamente
// `sin_documento` y comisión 0.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/finances/data/models/finances_transaction_model.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';

void main() {
  final fecha = DateTime(2026, 10, 3, 15, 30);

  Map<String, dynamic> docViejo() => {
        'title': 'Venta en feria',
        'description': 'Dos tazones de greda',
        'amount': 120000,
        'type': 'income',
        'category': 'Venta en feria',
        'date': Timestamp.fromDate(fecha),
        'monthKey': '2026-10',
      };

  group('FinancesTransactionModel · documentos sin los campos C-3', () {
    test('un documento viejo se lee sin romperse y asume los defectos', () {
      final model = FinancesTransactionModel.fromDoc('tx1', docViejo());

      expect(model.docType, TransactionDocType.sinDocumento);
      expect(model.platformFee, 0);
      expect(model.effectivePlatformFee, 0);
      expect(model.netAmount, 120000);
      expect(model.hasPlatformFee, isFalse);
      expect(model.monthKey, '2026-10');
    });

    test('al guardarlo no se inventan claves nuevas', () {
      final model = FinancesTransactionModel.fromDoc('tx1', docViejo());
      final data = model.toFirestore();

      expect(data.containsKey('docType'), isFalse);
      expect(data.containsKey('platformFee'), isFalse);
      expect(data.keys.toSet(), {
        'title',
        'description',
        'amount',
        'type',
        'category',
        'date',
        'monthKey',
      });
    });
  });

  group('FinancesTransactionModel · ida y vuelta con los campos C-3', () {
    test('boleta de venta con comisión sobrevive al viaje completo', () {
      final original = FinancesTransactionEntity(
        id: '',
        title: 'Pedido personalizado',
        description: 'Set de 6 platos',
        amount: 250000,
        type: TransactionType.income,
        date: fecha,
        category: 'Pedido personalizado',
        docType: TransactionDocType.boletaVenta,
        platformFee: 9500,
      );

      final data = FinancesTransactionModel.fromEntity(original).toFirestore();
      expect(data['docType'], 'boleta_venta');
      expect(data['platformFee'], 9500);

      final vuelta = FinancesTransactionModel.fromDoc('tx2', data);
      expect(vuelta.title, original.title);
      expect(vuelta.description, original.description);
      expect(vuelta.amount, original.amount);
      expect(vuelta.type, original.type);
      expect(vuelta.date, original.date);
      expect(vuelta.category, original.category);
      expect(vuelta.docType, TransactionDocType.boletaVenta);
      expect(vuelta.platformFee, 9500);
      // El neto NO se persiste: se deriva siempre.
      expect(data.containsKey('netAmount'), isFalse);
      expect(vuelta.netAmount, 240500);
    });

    test('boleta de honorarios sin comisión guarda el documento y nada más',
        () {
      final model = FinancesTransactionModel.fromDoc('tx3', {
        ...docViejo(),
        'docType': 'boleta_honorarios',
      });

      expect(model.docType, TransactionDocType.boletaHonorarios);
      expect(model.platformFee, 0);

      final data = model.toFirestore();
      expect(data['docType'], 'boleta_honorarios');
      expect(data.containsKey('platformFee'), isFalse);
    });

    test('los tres valores del contrato viajan con el texto exacto', () {
      expect(TransactionDocType.boletaVenta.wire, 'boleta_venta');
      expect(TransactionDocType.boletaHonorarios.wire, 'boleta_honorarios');
      expect(TransactionDocType.sinDocumento.wire, 'sin_documento');
      expect(TransactionDocType.fallback, TransactionDocType.sinDocumento);
    });
  });

  group('FinancesTransactionModel · datos defensivos', () {
    test('un docType desconocido cae en sin documento', () {
      final model = FinancesTransactionModel.fromDoc('tx4', {
        ...docViejo(),
        'docType': 'factura_electronica',
      });
      expect(model.docType, TransactionDocType.sinDocumento);
    });

    test('una comisión mayor que el monto se recorta al monto', () {
      final model = FinancesTransactionModel.fromDoc('tx5', {
        ...docViejo(),
        'platformFee': 500000,
      });
      expect(model.platformFee, 120000);
      expect(model.netAmount, 0);
    });

    test('una comisión negativa o inválida vale 0', () {
      final negativa = FinancesTransactionModel.fromDoc('tx6', {
        ...docViejo(),
        'platformFee': -3000,
      });
      final texto = FinancesTransactionModel.fromDoc('tx7', {
        ...docViejo(),
        'platformFee': 'tres mil',
      });

      expect(negativa.platformFee, 0);
      expect(negativa.netAmount, 120000);
      expect(texto.platformFee, 0);
      expect(texto.netAmount, 120000);
    });

    test('una categoría vieja que ya no está en la lista se conserva', () {
      final model = FinancesTransactionModel.fromDoc('tx8', {
        ...docViejo(),
        'category': 'Servicios',
      });
      expect(model.category, 'Servicios');
      expect(model.toFirestore()['category'], 'Servicios');
    });
  });

  group('FinancesTransactionModel · borrado de campos al actualizar', () {
    test('al actualizar sin comisión se manda borrar la clave', () {
      final model = FinancesTransactionModel.fromDoc('tx9', docViejo());
      final data = model.toFirestore(forUpdate: true);

      // Sin esto, quitarle la comisión a un movimiento la dejaría intacta en
      // el servidor: `update()` solo toca las claves que recibe.
      expect(data['platformFee'], isA<FieldValue>());
      expect(data['docType'], isA<FieldValue>());
    });

    test('al actualizar con comisión se manda el número, no un borrado', () {
      final model = FinancesTransactionModel.fromDoc('tx10', {
        ...docViejo(),
        'docType': 'boleta_venta',
        'platformFee': 4560,
      });
      final data = model.toFirestore(forUpdate: true);

      expect(data['platformFee'], 4560);
      expect(data['docType'], 'boleta_venta');
    });
  });
}
