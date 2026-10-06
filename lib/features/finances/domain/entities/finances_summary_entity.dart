import 'package:equatable/equatable.dart';

import '../../../../core/utils/month_labels.dart';

/// Resumen mensual calculado por el backend (`users/{uid}/months/{yyyy-MM}`).
///
/// El id del documento es el [monthKey]. Los totales NUNCA se escriben desde
/// el cliente: los recalcula el trigger `onTransactionWritten`.
class FinancesSummaryEntity extends Equatable {
  /// Clave del mes en formato `yyyy-MM` (id del documento).
  final String monthKey;
  final double totalIncome;
  final double totalExpenses;
  final int transactionCount;

  const FinancesSummaryEntity({
    required this.monthKey,
    required this.totalIncome,
    required this.totalExpenses,
    required this.transactionCount,
  });

  double get balance => totalIncome - totalExpenses;

  /// Progreso hacia una meta mensual (0..1). La meta vive en el perfil del
  /// usuario, por eso se recibe como parámetro.
  double goalProgress(final double monthlyGoal) =>
      monthlyGoal > 0 ? (totalIncome / monthlyGoal).clamp(0.0, 1.0) : 0.0;

  /// Etiqueta legible, p. ej. "Marzo 2025".
  String get month => monthLabelFromKey(monthKey);

  /// Primer día del mes representado, o `null` si la clave es inválida.
  DateTime? get firstDay {
    final parts = monthKey.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month, 1);
  }

  @override
  List<Object?> get props =>
      [monthKey, totalIncome, totalExpenses, transactionCount];
}

/// Deriva la clave `yyyy-MM` de una fecha.
String monthKeyFromDate(final DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

/// Convierte `yyyy-MM` en "Marzo 2025". Si la clave es inválida la devuelve
/// tal cual.
///
/// Los nombres de mes viven en `core/utils/month_labels.dart`; aquí solo se
/// conserva el nombre de la función porque es el que consume la entidad.
String monthLabelFromKey(final String monthKey) =>
    monthLabelFromMonthKey(monthKey);
