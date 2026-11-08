import '../entities/user_profile_entity.dart';

abstract class UserProfileRepository {
  /// Perfil en tiempo real; `null` mientras el usuario no complete el
  /// onboarding. Los errores se propagan por el stream.
  Stream<UserProfileEntity?> watchProfile();

  /// Crea o actualiza el perfil (merge sobre `users/{uid}`).
  Future<void> saveProfile(UserProfileEntity profile);
}
