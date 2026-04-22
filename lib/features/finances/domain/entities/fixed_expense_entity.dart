import 'package:equatable/equatable.dart';

class FixedExpenseEntity extends Equatable {
  final String id;
  final String name;
  final double amount;
  final String category;

  const FixedExpenseEntity({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
  });

  @override
  List<Object?> get props => [id, name, amount, category];
}
