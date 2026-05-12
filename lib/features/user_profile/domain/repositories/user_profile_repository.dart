import '../entities/user_profile_entity.dart';

abstract class UserProfileRepository {
  Future<UserProfileEntity> getProfile();
  Future<void> saveProfile(UserProfileEntity profile);
  Future<void> updateProfile(UserProfileEntity profile);
}