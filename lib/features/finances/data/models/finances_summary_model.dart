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
    super.totalPlatformFees,
    super.hasPlatformFeesTotal,
  });

  /// Construye el modelo desde un documento. Nunca lanza por tipos
  /// inesperados: usa valores por defecto seguros y lo registra.
  factory FinancesSummaryModel.fromDoc(
    final String id,
    final Map<String, dynamic> data,
  ) {
    // `totalPlatformFees` es POSTERIOR al contrato C-3: un mes escrito antes
    // no lo trae. Por eso no pasa por `_double` —que avisaría por un campo
    // que legítimamente puede faltar— y se registra aparte si es un dato
    // ausente (normal) o de un tipo imposible (un fallo real).
    final rawFees = data['totalPlatformFees'];
    if (rawFees != null && rawFees is! num) {
      debugPrint(
        'FinancesSummaryModel[$id]: totalPlatformFees no es num ($rawFees)',
      );
    }

    return FinancesSummaryModel(
      monthKey: id,
      totalIncome: _double(data['totalIncome'], id, 'totalIncome'),
      totalExpenses: _double(data['totalExpenses'], id, 'totalExpenses'),
      totalPlatformFees: rawFees is num ? rawFees.toDouble() : 0,
      hasPlatformFeesTotal: rawFees is num,
      transactionCount:
          _double(data['transactionCount'], id, 'transactionCount').toInt(),
    );
  }

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
