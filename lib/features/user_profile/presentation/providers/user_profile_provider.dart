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

  void updateFromSetup({
    required final String name,
    required final String businessName,
    required final String businessType,
    required final String currency,
    required final double monthlyGoal,
  }) {
    final safeName = name.trim();
    final safeBusinessName = businessName.trim();
    if (safeName.isEmpty || safeBusinessName.isEmpty) return;

    final initialsParts = safeName
        .split(' ')
        .where((final part) => part.trim().isNotEmpty)
        .take(2)
        .map((final part) => part.trim()[0].toUpperCase())
        .toList();

    final initials = initialsParts.isEmpty ? 'IA' : initialsParts.join();

    _profile = (_profile ?? const UserProfileEntity(
      id: 'local-user',
      name: 'Usuario',
      businessName: 'Mi Negocio',
      businessType: 'Taller',
      currency: 'MXN',
      monthlyGoal: 0,
      isPro: false,
      avatarInitials: 'IA',
    ))
        .copyWith(
      name: safeName,
      businessName: safeBusinessName,
      businessType: businessType,
      currency: currency,
      monthlyGoal: monthlyGoal,
      avatarInitials: initials,
    );

    notifyListeners();
  }
}
