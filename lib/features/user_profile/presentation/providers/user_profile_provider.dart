import 'package:flutter/foundation.dart';
import '../../data/repositories/mock_user_profile_repository.dart';
import '../../domain/entities/user_profile_entity.dart';

class UserProfileProvider extends ChangeNotifier {
  final MockUserProfileRepository _repository;

  UserProfileEntity? _profile;
  bool _isLoading = false;

  UserProfileProvider({required final MockUserProfileRepository repository})
      : _repository = repository {
    _load();
  }

  UserProfileEntity? get profile => _profile;
  bool get isLoading => _isLoading;

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
    _profile = await _repository.getProfile();
    _isLoading = false;
    notifyListeners();
  }
}
