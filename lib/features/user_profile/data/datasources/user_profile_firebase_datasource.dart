import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_model.dart';
import '../../domain/entities/user_profile_entity.dart';

/// Firebase data source for user profiles.
/// userId is injected at construction time for consistent scoping.
class UserProfileFirebaseDatasource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId;
  static const String _collection = 'user_profiles';

  UserProfileFirebaseDatasource({required String userId}) : _userId = userId;

  Future<UserProfileEntity> getProfile() async {
    final docSnapshot = await _firestore
        .collection(_collection)
        .doc(_userId)
        .get();

    if (!docSnapshot.exists) {
      throw Exception('Profile not found for user: $_userId');
    }

    final data = docSnapshot.data() as Map<String, dynamic>;
    return UserProfileModel.fromJson(data);
  }

  Future<void> saveProfile(UserProfileModel profile) async {
    await _firestore
        .collection(_collection)
        .doc(_userId)
        .set(profile.toJson());
  }

  Future<void> updateProfile(UserProfileModel profile) async {
    await _firestore
        .collection(_collection)
        .doc(_userId)
        .update(profile.toJson());
  }
}