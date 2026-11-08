import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/hourly_rate_model.dart';

/// Persistencia del valor hora en el mapa `hourlyRate` de `users/{uid}`.
///
/// El nombre "Local" es histórico: la persistencia offline la aporta la caché
/// de Firestore. Toda escritura usa `merge` para no pisar el perfil.
class HourlyRateLocalDataSource {
  final FirebaseFirestore _firestore;
  final String _userId;

  HourlyRateLocalDataSource({
    required final FirebaseFirestore firestore,
    required final String userId,
  })  : _firestore = firestore,
        _userId = userId;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(_userId);

  static HourlyRateModel? _fromData(final Map<String, dynamic>? data) {
    final raw = data?['hourlyRate'];
    if (raw is! Map<String, dynamic>) return null;
    final hours = (raw['availableHoursPerMonth'] as num?)?.toDouble() ?? 0;
    if (hours <= 0) return null;
    return HourlyRateModel.fromJson(raw);
  }

  /// Valor hora en tiempo real; `null` si no está configurado. Los errores se
  /// propagan por el stream.
  Stream<HourlyRateModel?> watchHourlyRate() =>
      _userDoc.snapshots().map((snapshot) => _fromData(snapshot.data()));

  Future<void> saveHourlyRate(final HourlyRateModel model) => _userDoc.set(
        {
          'hourlyRate': model.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
}
