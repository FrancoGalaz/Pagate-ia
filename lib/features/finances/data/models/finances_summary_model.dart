import '../entities/finances_summary_entity.dart';
import '../entities/fixed_expense_entity.dart';
import 'fixed_expense_model.dart';

/// Model for FinancesSummary with manual JSON serialization.
class FinancesSummaryModel extends FinancesSummaryEntity {
  const FinancesSummaryModel({
    required super.month,
    required super.totalIncome,
    required super.totalExpenses,
    required super.monthlyGoal,
    required super.fixedExpenses,
  });

  factory FinancesSummaryModel.fromJson(Map<String, dynamic> json) {
    final fixedExpensesList = (json['fixedExpenses'] as List<dynamic>?)
            ?.map((e) =>
                FixedExpenseModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return FinancesSummaryModel(
      month: json['month'] as int,
      totalIncome: (json['totalIncome'] as num).toDouble(),
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      monthlyGoal: (json['monthlyGoal'] as num).toDouble(),
      fixedExpenses: fixedExpensesList,
    );
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'monthlyGoal': monthlyGoal,
        'fixedExpenses':
            fixedExpenses.map((e) => (e as FixedExpenseModel).toJson()).toList(),
      };

  factory FinancesSummaryModel.fromEntity(FinancesSummaryEntity entity) {
    return FinancesSummaryModel(
      month: entity.month,
      totalIncome: entity.totalIncome,
      totalExpenses: entity.totalExpenses,
      monthlyGoal: entity.monthlyGoal,
      fixedExpenses: entity.fixedExpenses
          .map((e) => FixedExpenseModel.fromEntity(e))
          .toList(),
    );
  }
}