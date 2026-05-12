import '../../domain/entities/fixed_expense_entity.dart';

/// Model for FixedExpense with manual JSON serialization.
class FixedExpenseModel extends FixedExpenseEntity {
  const FixedExpenseModel({
    required super.id,
    required super.name,
    required super.amount,
    required super.category,
  });

  factory FixedExpenseModel.fromJson(Map<String, dynamic> json) {
    return FixedExpenseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'category': category,
      };

  factory FixedExpenseModel.fromEntity(FixedExpenseEntity entity) {
    return FixedExpenseModel(
      id: entity.id,
      name: entity.name,
      amount: entity.amount,
      category: entity.category,
    );
  }
}