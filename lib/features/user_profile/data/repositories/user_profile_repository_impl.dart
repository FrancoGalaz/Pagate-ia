import '../../domain/repositories/user_profile_repository.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../datasources/user_profile_firebase_datasource.dart';
import '../models/user_profile_model.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileFirebaseDatasource _datasource;

  UserProfileRepositoryImpl({required UserProfileFirebaseDatasource datasource})
      : _datasource = datasource;

  @override
  Future<UserProfileEntity> getProfile() async {
    return await _datasource.getProfile();
  }

  @override
  Future<void> saveProfile(UserProfileEntity profile) async {
    final profileModel = UserProfileModel.fromEntity(profile);
    await _datasource.saveProfile(profileModel);
  }

  @override
  Future<void> updateProfile(UserProfileEntity profile) async {
    final profileModel = UserProfileModel.fromEntity(profile);
    await _datasource.updateProfile(profileModel);
  }
}