import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/config/firebase_errors.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Estado del perfil del usuario, alimentado por el stream de `users/{uid}`.
///
/// - [isLoading]: aún no llegó el primer snapshot.
/// - [profile]: `null` cuando el usuario todavía no completó el onboarding.
/// - [error]: fallo de lectura (permisos, red). [retry] vuelve a suscribirse.
///
/// Los guardados fallidos se relanzan al llamador para que la pantalla los
/// muestre; nunca se silencian.
class UserProfileProvider extends ChangeNotifier {
  final UserProfileRepository _repository;

  StreamSubscription<UserProfileEntity?>? _subscription;
  UserProfileEntity? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  UserProfileProvider({required UserProfileRepository repository})
      : _repository = repository {
    _subscribe();
  }

  UserProfileEntity? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  void _subscribe() {
    _subscription?.cancel();
    _isLoading = true;
    _error = null;
    _subscription = _repository.watchProfile().listen(
      (final profile) {
        _profile = profile;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (final Object e) {
        _isLoading = false;
        _error = describeFirebaseError(e);
        notifyListeners();
      },
    );
  }

  /// Vuelve a suscribirse al perfil tras un error.
  void retry() {
    _subscribe();
    notifyListeners();
  }

  /// Guarda el perfil completo. Relanza el error tras registrarlo.
  Future<void> saveProfile(final UserProfileEntity profile) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _repository.saveProfile(profile);
      // El stream actualizará [_profile]; se refleja ya para evitar parpadeos.
      _profile = profile;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Crea o actualiza el perfil con los datos del onboarding / Editar perfil.
  /// Lanza [ArgumentError] si nombre o negocio vienen vacíos.
  Future<void> updateFromSetup({
    required String name,
    required String businessName,
    required String businessType,
    required String currency,
    required double monthlyGoal,
  }) {
    final safeName = name.trim();
    final safeBusinessName = businessName.trim();
    if (safeName.isEmpty || safeBusinessName.isEmpty) {
      throw ArgumentError('Nombre y negocio son obligatorios.');
    }

    final base = _profile ??
        UserProfileEntity(
          id: '',
          name: safeName,
          businessName: safeBusinessName,
          businessType: businessType,
          currency: currency,
          monthlyGoal: monthlyGoal,
          isPro: false,
          avatarInitials: UserProfileEntity.initialsFor(safeName),
        );

    return saveProfile(
      base.copyWith(
        name: safeName,
        businessName: safeBusinessName,
        businessType: businessType,
        currency: currency,
        monthlyGoal: monthlyGoal,
        avatarInitials: UserProfileEntity.initialsFor(safeName),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
