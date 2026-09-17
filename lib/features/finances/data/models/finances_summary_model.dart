import 'package:flutter/foundation.dart';
import '../../domain/entities/finances_summary_entity.dart';

/// Modelo de resumen mensual leído desde `users/{uid}/months/{yyyy-MM}`.
/// Solo lectura: los meses los escribe el backend.
class FinancesSummaryModel extends FinancesSummaryEntity {
  const FinancesSummaryModel({
    required super.monthKey,
    required super.totalIncome,
    required super.totalExpenses,
    required super.transactionCount,
  });

  /// Construye el modelo desde un documento. Nunca lanza por tipos
  /// inesperados: usa valores por defecto seguros y lo registra.
  factory FinancesSummaryModel.fromDoc(
    final String id,
    final Map<String, dynamic> data,
  ) =>
      FinancesSummaryModel(
        monthKey: id,
        totalIncome: _double(data['totalIncome'], id, 'totalIncome'),
        totalExpenses: _double(data['totalExpenses'], id, 'totalExpenses'),
        transactionCount:
            _double(data['transactionCount'], id, 'transactionCount').toInt(),
      );

  static double _double(
    final Object? value,
    final String id,
    final String field,
  ) {
    if (value is num) return value.toDouble();
    debugPrint('FinancesSummaryModel[$id]: $field no es num ($value)');
    return 0;
  }
}
