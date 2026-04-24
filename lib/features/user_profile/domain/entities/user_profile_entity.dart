import 'package:equatable/equatable.dart';

class UserProfileEntity extends Equatable {
  final String id;
  final String name;
  final String businessName;
  final String businessType;
  final String currency;
  final double monthlyGoal;
  final bool isPro;
  final String avatarInitials;

  const UserProfileEntity({
    required this.id,
    required this.name,
    required this.businessName,
    required this.businessType,
    required this.currency,
    required this.monthlyGoal,
    required this.isPro,
    required this.avatarInitials,
  });

  UserProfileEntity copyWith({
    final String? id,
    final String? name,
    final String? businessName,
    final String? businessType,
    final String? currency,
    final double? monthlyGoal,
    final bool? isPro,
    final String? avatarInitials,
  }) =>
      UserProfileEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        businessName: businessName ?? this.businessName,
        businessType: businessType ?? this.businessType,
        currency: currency ?? this.currency,
        monthlyGoal: monthlyGoal ?? this.monthlyGoal,
        isPro: isPro ?? this.isPro,
        avatarInitials: avatarInitials ?? this.avatarInitials,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        businessName,
        businessType,
        currency,
        monthlyGoal,
        isPro,
        avatarInitials,
      ];
}
