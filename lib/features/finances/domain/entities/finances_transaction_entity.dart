import 'package:equatable/equatable.dart';

enum TransactionType { income, expense }

class FinancesTransactionEntity extends Equatable {
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

  @override
  List<Object?> get props => [id, title, description, amount, type, date, category];
}