import '../entities/user_profile_entity.dart';

class UserProfileModel extends UserProfileEntity {
  const UserProfileModel({
    required super.id,
    required super.name,
    required super.businessName,
    required super.businessType,
    required super.currency,
    required super.monthlyGoal,
    required super.isPro,
    required super.avatarInitials,
  });

  factory UserProfileModel.fromEntity(UserProfileEntity entity) {
    return UserProfileModel(
      id: entity.id,
      name: entity.name,
      businessName: entity.businessName,
      businessType: entity.businessType,
      currency: entity.currency,
      monthlyGoal: entity.monthlyGoal,
      isPro: entity.isPro,
      avatarInitials: entity.avatarInitials,
    );
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      businessName: json['businessName'] as String,
      businessType: json['businessType'] as String,
      currency: json['currency'] as String,
      monthlyGoal: (json['monthlyGoal'] as num).toDouble(),
      isPro: json['isPro'] as bool,
      avatarInitials: json['avatarInitials'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'businessName': businessName,
      'businessType': businessType,
      'currency': currency,
      'monthlyGoal': monthlyGoal,
      'isPro': isPro,
      'avatarInitials': avatarInitials,
    };
  }
}