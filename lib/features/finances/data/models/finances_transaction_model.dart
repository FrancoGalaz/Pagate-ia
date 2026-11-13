import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/finances_transaction_entity.dart';

/// Modelo de transacción con serialización manual hacia/desde Firestore.
///
/// El documento NO contiene `id` ni `userId`: el id es el del documento y el
/// usuario viene dado por la ruta `users/{uid}/transactions`.
class FinancesTransactionModel extends FinancesTransactionEntity {
  const FinancesTransactionModel({
    required super.id,
    required super.title,
    required super.description,
    required super.amount,
    required super.type,
    required super.date,
    required super.category,
    super.docType,
    super.platformFee,
  });

  /// Construye el modelo desde un documento. Nunca lanza por tipos
  /// inesperados: usa valores por defecto seguros y lo registra.
  factory FinancesTransactionModel.fromDoc(
    final String id,
    final Map<String, dynamic> data,
  ) {
    final rawType = data['type'];
    TransactionType type;
    if (rawType == 'income') {
      type = TransactionType.income;
    } else if (rawType == 'expense') {
      type = TransactionType.expense;
    } else {
      debugPrint(
        'FinancesTransactionModel[$id]: type inesperado "$rawType", '
        'se asume expense',
      );
      type = TransactionType.expense;
    }

    final amount = _double(data['amount'], id, 'amount');

    return FinancesTransactionModel(
      id: id,
      title: _string(data['title'], id, 'title'),
      description: _string(data['description'], id, 'description'),
      amount: amount,
      type: type,
      date: _date(data['date'], id),
      category: _string(data['category'], id, 'category'),
      docType: _docType(data['docType'], id),
      platformFee: _platformFee(data['platformFee'], id, amount),
    );
  }

  /// Campos que se escriben en Firestore al crear o actualizar. No incluye
  /// `createdAt`/`updatedAt`: los agrega el datasource con serverTimestamp.
  ///
  /// `docType` y `platformFee` son **opcionales** por contrato (C-3): si el
  /// documento no los trae se asumen `sin_documento` y 0. Por eso aquí se
  /// omiten cuando valen exactamente eso, en lugar de escribir un dato que no
  /// aporta nada: el documento queda idéntico al de antes del contrato y no
  /// hay dos formas distintas de decir lo mismo.
  ///
  /// [forUpdate] sirve para el caso contrario: al editar un movimiento que
  /// **sí** tenía comisión y dejarla en 0, un `update()` con la clave omitida
  /// conservaría el valor viejo en el servidor. Con `forUpdate: true` se
  /// manda `FieldValue.delete()` y el campo desaparece de verdad. No se puede
  /// usar al crear: `FieldValue.delete()` solo es válido en `update` y en
  /// `set(merge: true)`.
  Map<String, dynamic> toFirestore({final bool forUpdate = false}) {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'amount': amount,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'category': category,
      'date': Timestamp.fromDate(date),
      'monthKey': monthKey,
    };

    if (docType != TransactionDocType.fallback) {
      map['docType'] = docType.wire;
    } else if (forUpdate) {
      map['docType'] = FieldValue.delete();
    }

    final fee = effectivePlatformFee;
    if (fee > 0) {
      map['platformFee'] = fee;
    } else if (forUpdate) {
      map['platformFee'] = FieldValue.delete();
    }

    return map;
  }

  factory FinancesTransactionModel.fromEntity(
    final FinancesTransactionEntity entity,
  ) =>
      FinancesTransactionModel(
        id: entity.id,
        title: entity.title,
        description: entity.description,
        amount: entity.amount,
        type: entity.type,
        date: entity.date,
        category: entity.category,
        docType: entity.docType,
        platformFee: entity.platformFee,
      );

  static String _string(
    final Object? value,
    final String id,
    final String field,
  ) {
    if (value is String) return value;
    if (value != null) {
      debugPrint(
        'FinancesTransactionModel[$id]: $field no es String ($value)',
      );
    }
    return '';
  }

  static double _double(
    final Object? value,
    final String id,
    final String field,
  ) {
    if (value is num) return value.toDouble();
    debugPrint('FinancesTransactionModel[$id]: $field no es num ($value)');
    return 0;
  }

  /// Campo opcional: ausente es válido y silencioso. Solo se registra un
  /// valor presente que no se reconoce.
  static TransactionDocType _docType(final Object? value, final String id) {
    if (value == null) return TransactionDocType.fallback;
    final parsed = TransactionDocType.fromWire(value);
    if (value is! String || parsed.wire != value) {
      debugPrint(
        'FinancesTransactionModel[$id]: docType inesperado "$value", '
        'se asume ${TransactionDocType.fallback.wire}',
      );
    }
    return parsed;
  }

  /// Campo opcional acotado a `[0, amount]`. Un valor fuera de rango se
  /// recorta y se registra: la entidad deriva el neto como
  /// `amount - platformFee` y un neto negativo sería una cifra falsa.
  static double _platformFee(
    final Object? value,
    final String id,
    final double amount,
  ) {
    if (value == null) return 0;
    if (value is! num || !value.isFinite) {
      debugPrint(
        'FinancesTransactionModel[$id]: platformFee no es num ($value), '
        'se asume 0',
      );
      return 0;
    }
    final fee = value.toDouble();
    if (fee < 0) {
      debugPrint(
        'FinancesTransactionModel[$id]: platformFee negativa ($fee), '
        'se asume 0',
      );
      return 0;
    }
    if (fee > amount) {
      debugPrint(
        'FinancesTransactionModel[$id]: platformFee ($fee) mayor que amount '
        '($amount), se recorta al monto',
      );
      return amount;
    }
    return fee;
  }

  static DateTime _date(final Object? value, final String id) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    debugPrint('FinancesTransactionModel[$id]: date inválida ($value)');
    return DateTime.now();
  }
}
