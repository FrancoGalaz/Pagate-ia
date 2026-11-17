import 'package:equatable/equatable.dart';

/// Gasto fijo recurrente (`users/{uid}/fixedExpenses/{id}`).
class FixedExpenseEntity extends Equatable {
  /// Id del documento en Firestore.
  final String id;
  final String name;
  final double amount;

  const FixedExpenseEntity({
    required this.id,
    required this.name,
    required this.amount,
  });

  @override
  List<Object?> get props => [id, name, amount];
}
