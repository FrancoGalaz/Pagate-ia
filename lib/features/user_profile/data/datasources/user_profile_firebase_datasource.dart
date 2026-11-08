import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile_model.dart';

/// Acceso a `users/{uid}`.
///
/// Es el mismo documento que usa `hourly_value`, por eso toda escritura usa
/// `SetOptions(merge: true)`: nunca se pisan `hourlyRate` ni `plan`.
class UserProfileFirebaseDatasource {
  final FirebaseFirestore _firestore;
  final String _userId;

  /// Si el último snapshot observado tenía `createdAt`. Permite escribirlo
  /// solo en la creación sin una lectura extra antes de cada guardado.
  bool _hasCreatedAt = false;

  UserProfileFirebaseDatasource({
    required final FirebaseFirestore firestore,
    required final String userId,
  })  : _firestore = firestore,
        _userId = userId;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(_userId);

  /// Emite `null` mientras no exista perfil. Los errores (permisos, red) se
  /// propagan por el stream; nunca se convierten en `null`.
  Stream<UserProfileModel?> watchProfile() => _doc.snapshots().map((snapshot) {
        _hasCreatedAt = snapshot.data()?['createdAt'] != null;
        return UserProfileModel.fromSnapshot(snapshot);
      });

  Future<void> saveProfile(final UserProfileModel profile) => _doc.set(
        {
          ...profile.toFirestore(),
          if (!_hasCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
}
