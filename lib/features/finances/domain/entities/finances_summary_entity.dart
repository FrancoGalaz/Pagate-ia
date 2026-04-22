import 'package:equatable/equatable.dart';
import 'fixed_expense_entity.dart';

class FinancesSummaryEntity extends Equatable {
  final String month; // e.g. "Marzo 2025"
  final double totalIncome;
  final double totalExpenses;
  final double monthlyGoal;
  final List<FixedExpenseEntity> fixedExpenses;

  const FinancesSummaryEntity({
    required this.month,
    required this.totalIncome,
    required this.totalExpenses,
    required this.monthlyGoal,
    required this.fixedExpenses,
  });

  double get balance => totalIncome - totalExpenses;

  double get goalProgress =>
      monthlyGoal > 0 ? (totalIncome / monthlyGoal).clamp(0.0, 1.0) : 0.0;

  @override
  List<Object?> get props =>
      [month, totalIncome, totalExpenses, monthlyGoal, fixedExpenses];
}
