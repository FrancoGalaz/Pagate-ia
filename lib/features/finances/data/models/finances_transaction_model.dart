import '../entities/finances_transaction_entity.dart';

/// Model for FinancesTransaction with manual JSON serialization.
/// No code generation required.
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

  factory FinancesTransactionModel.fromJson(Map<String, dynamic> json) {
    TransactionType type;
    if (json['type'] == 'income') {
      type = TransactionType.income;
    } else if (json['type'] == 'expense') {
      type = TransactionType.expense;
    } else {
      throw FormatException('Invalid TransactionType: ${json['type']}');
    }

    return FinancesTransactionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      type: type,
      date: (json['date'] as String).isNotEmpty
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      category: json['category'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'amount': amount,
        'type': type == TransactionType.income ? 'income' : 'expense',
        'date': date.toIso8601String(),
        'category': category,
      };

  factory FinancesTransactionModel.fromEntity(
      FinancesTransactionEntity entity) {
    return FinancesTransactionModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      amount: entity.amount,
      type: entity.type,
      date: entity.date,
      category: entity.category,
    );
  }
}