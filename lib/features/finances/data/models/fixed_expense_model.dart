import 'package:flutter/foundation.dart';
import '../../domain/entities/fixed_expense_entity.dart';

/// Modelo de gasto fijo con serialización manual hacia/desde Firestore.
class FixedExpenseModel extends FixedExpenseEntity {
  const FixedExpenseModel({
    required super.id,
    required super.name,
    required super.amount,
  });

  /// Construye el modelo desde un documento. Nunca lanza por tipos
  /// inesperados: usa valores por defecto seguros y lo registra.
  factory FixedExpenseModel.fromDoc(
    final String id,
    final Map<String, dynamic> data,
  ) {
    final rawName = data['name'];
    final rawAmount = data['amount'];
    if (rawName is! String) {
      debugPrint('FixedExpenseModel[$id]: name no es String ($rawName)');
    }
    if (rawAmount is! num) {
      debugPrint('FixedExpenseModel[$id]: amount no es num ($rawAmount)');
    }
    return FixedExpenseModel(
      id: id,
      name: rawName is String ? rawName : '',
      amount: rawAmount is num ? rawAmount.toDouble() : 0,
    );
  }

  /// Campos que se escriben en Firestore (sin `id`; `createdAt`/`updatedAt`
  /// los agrega el datasource).
  Map<String, dynamic> toFirestore() => {
        'name': name,
        'amount': amount,
      };
}
