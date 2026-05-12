import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shop_settings_model.dart';

/// Service for reading and writing shop settings.
///
/// Firestore layout:
///   settings/ (collection)
///     default  (single document — all fields)
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _collection = 'settings';
  static const String _document = 'default';

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection).doc(_document);

  // ── Read ─────────────────────────────────────────────────────

  /// Fetch settings once.  Returns defaults if the document doesn't exist yet.
  Future<ShopSettingsModel> getSettings() async {
    try {
      final snap = await _ref.get();
      if (!snap.exists || snap.data() == null) return const ShopSettingsModel();
      return ShopSettingsModel.fromFirestore(snap.id, snap.data()!);
    } catch (e) {
      // Return safe defaults so the app never hard-crashes on a missing doc.
      return const ShopSettingsModel();
    }
  }

  /// Real-time stream of settings — customer app subscribes to this so
  /// changes by the admin take effect immediately without a restart.
  Stream<ShopSettingsModel> watchSettings() {
    return _ref.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return const ShopSettingsModel();
      return ShopSettingsModel.fromFirestore(snap.id, snap.data()!);
    });
  }

  // ── Write ────────────────────────────────────────────────────

  /// Persist the full settings document.  Uses [SetOptions.merge] so any
  /// future fields added by other parts of the app are not wiped.
  Future<void> saveSettings(ShopSettingsModel settings) async {
    await _ref.set(
      {
        ...settings.toFirestore(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Convenience: patch a single boolean toggle without loading the full doc.
  Future<void> setHolidayMode(bool enabled) async {
    await _ref.set(
      {'holiday_mode': enabled, 'updated_at': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> setOrderPause(bool paused) async {
    await _ref.set(
      {'order_pause': paused, 'updated_at': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Update minimum order value
  Future<void> setMinOrderValue(double minValue) async {
    await _ref.set(
      {'min_order_value': minValue, 'updated_at': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}