import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hourly_rate_model.dart';

/// Local data source for HourlyRate using Firestore with offline persistence.
/// Firestore automatically handles caching for offline-first functionality.
class HourlyRateLocalDataSource {
  final FirebaseFirestore _firestore;
  final String _userId;

  HourlyRateLocalDataSource({
    required final FirebaseFirestore firestore,
    required final String userId,
  })  : _firestore = firestore,
        _userId = userId;

  /// Collection reference for user preferences.
  CollectionReference get _userCollection => _firestore.collection('users');

  /// Document reference for the current user's hourly rate configuration.
  DocumentReference get _hourlyRateDoc => _userCollection.doc(_userId);

  /// Fetches the hourly rate from Firestore (with offline cache support).
  Future<HourlyRateModel?> getHourlyRate() async {
    try {
      final doc = await _hourlyRateDoc.get();

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('hourlyRate')) return null;

      return HourlyRateModel.fromJson(
          data['hourlyRate'] as Map<String, dynamic>);
    } catch (e) {
      // In case of offline mode or errors, return null gracefully.
      return null;
    }
  }

  /// Saves the hourly rate to Firestore.
  /// Uses merge to avoid overwriting other user data fields.
  Future<void> saveHourlyRate(final HourlyRateModel model) async {
    await _hourlyRateDoc.set(
      {
        'hourlyRate': model.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Checks if configuration exists.
  Future<bool> hasConfiguration() async {
    final rate = await getHourlyRate();
    return rate != null;
  }
}
