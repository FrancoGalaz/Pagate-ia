import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_profile_entity.dart';

/// Modelo de persistencia de [UserProfileEntity] sobre `users/{uid}`.
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

  factory UserProfileModel.fromEntity(final UserProfileEntity entity) =>
      UserProfileModel(
        id: entity.id,
        name: entity.name,
        businessName: entity.businessName,
        businessType: entity.businessType,
        currency: entity.currency,
        monthlyGoal: entity.monthlyGoal,
        isPro: entity.isPro,
        avatarInitials: entity.avatarInitials,
      );

  /// `null` si el documento no existe o todavía no tiene perfil (por ejemplo,
  /// solo contiene `hourlyRate`). Un perfil existe cuando hay `name`.
  static UserProfileModel? fromSnapshot(
    final DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return null;

    final name = data['name'];
    if (name is! String || name.trim().isEmpty) return null;

    return UserProfileModel(
      id: snapshot.id,
      name: name,
      businessName: data['businessName'] as String? ?? '',
      businessType: data['businessType'] as String? ?? '',
      currency: data['currency'] as String? ?? kDefaultCurrency,
      monthlyGoal: (data['monthlyGoal'] as num?)?.toDouble() ?? 0,
      isPro: data['plan'] == 'pro',
      avatarInitials: data['avatarInitials'] as String? ??
          UserProfileEntity.initialsFor(name),
    );
  }

  /// Campos que escribe el cliente. Nunca `plan` (lo escribe el backend) ni
  /// `id` (es el id del documento).
  Map<String, dynamic> toFirestore() => {
        'name': name,
        'businessName': businessName,
        'businessType': businessType,
        'currency': currency,
        'monthlyGoal': monthlyGoal,
        'avatarInitials': avatarInitials,
      };
}
