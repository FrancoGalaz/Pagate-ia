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

    return FinancesTransactionModel(
      id: id,
      title: _string(data['title'], id, 'title'),
      description: _string(data['description'], id, 'description'),
      amount: _double(data['amount'], id, 'amount'),
      type: type,
      date: _date(data['date'], id),
      category: _string(data['category'], id, 'category'),
    );
  }

  /// Campos que se escriben en Firestore al crear o actualizar. No incluye
  /// `createdAt`/`updatedAt`: los agrega el datasource con serverTimestamp.
  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'amount': amount,
        'type': type == TransactionType.income ? 'income' : 'expense',
        'category': category,
        'date': Timestamp.fromDate(date),
        'monthKey': monthKey,
      };

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
