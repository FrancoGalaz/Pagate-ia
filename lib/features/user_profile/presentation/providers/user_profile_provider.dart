import 'package:flutter/foundation.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../domain/entities/user_profile_entity.dart';

class UserProfileProvider extends ChangeNotifier {
  final UserProfileRepository _repository;

  UserProfileEntity? _profile;
  bool _isLoading = false;

  UserProfileProvider({required UserProfileRepository repository})
      : _repository = repository {
    _load();
  }

  UserProfileEntity? get profile => _profile;
  bool get isLoading => _isLoading;

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _profile = await _repository.getProfile();
    } catch (_) {
      // Profile doesn't exist yet (new user) — start with default
      _profile = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateFromSetup({
    required String name,
    required String businessName,
    required String businessType,
    required String currency,
    required double monthlyGoal,
  }) async {
    final safeName = name.trim();
    final safeBusinessName = businessName.trim();
    if (safeName.isEmpty || safeBusinessName.isEmpty) return;

    final initialsParts = safeName
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase())
        .toList();

    final initials = initialsParts.isEmpty ? 'IA' : initialsParts.join();

    final updatedProfile = (_profile ?? const UserProfileEntity(
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

    // Persist to Firestore
    try {
      await _repository.saveProfile(updatedProfile);
    } catch (_) {
      // Fallback: saveProfile failed, try updateProfile
      await _repository.updateProfile(updatedProfile);
    }

    _profile = updatedProfile;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _load();
  }
}