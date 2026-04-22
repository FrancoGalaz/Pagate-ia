import '../../domain/entities/user_profile_entity.dart';
import '../../../../core/constants/app_mock_data.dart';

class MockUserProfileRepository {
  Future<UserProfileEntity> getProfile() async => AppMockData.user;
}
