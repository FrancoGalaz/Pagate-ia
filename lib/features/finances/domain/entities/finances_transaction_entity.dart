import 'package:equatable/equatable.dart';
import 'finances_summary_entity.dart';

enum TransactionType { income, expense }

/// Movimiento registrado por el usuario (`users/{uid}/transactions/{txId}`).
class FinancesTransactionEntity extends Equatable {
  /// Id del documento en Firestore. Vacío para una transacción aún no guardada.
  final String id;
  final String title;
  final String description;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String category;

  const FinancesTransactionEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
  });

  /// Clave `yyyy-MM` derivada de [date].
  String get monthKey => monthKeyFromDate(date);

  bool get isIncome => type == TransactionType.income;

  FinancesTransactionEntity copyWith({
    final String? id,
    final String? title,
    final String? description,
    final double? amount,
    final TransactionType? type,
    final DateTime? date,
    final String? category,
  }) =>
      FinancesTransactionEntity(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        date: date ?? this.date,
        category: category ?? this.category,
      );

  @override
  List<Object?> get props =>
      [id, title, description, amount, type, date, category];
}
