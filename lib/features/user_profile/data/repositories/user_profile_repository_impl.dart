import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/user_profile_firebase_datasource.dart';
import '../models/user_profile_model.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileFirebaseDatasource _datasource;

  UserProfileRepositoryImpl({
    required UserProfileFirebaseDatasource datasource,
  }) : _datasource = datasource;

  @override
  Stream<UserProfileEntity?> watchProfile() => _datasource.watchProfile();

  @override
  Future<void> saveProfile(final UserProfileEntity profile) =>
      _datasource.saveProfile(UserProfileModel.fromEntity(profile));
}
