import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles all Firestore mutations for the customer profile document.
///
/// Document path: users/{phone}
///
/// Fields written:
///   name       String    Display name set by user
///   phone      String    Canonical +91-prefixed phone number
///   updated_at Timestamp Server-side timestamp of last profile edit
class UserProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Update display name ──────────────────────────────────────────────────

  /// Writes [name] to users/{phone} and touches updated_at.
  ///
  /// Uses merge so other fields (role, createdAt, fcmToken…) are preserved.
  Future<void> updateName({
    required String phone,
    required String name,
  }) async {
    await _db.collection('users').doc(phone).set(
      {
        'name': name,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ── Migrate phone number ─────────────────────────────────────────────────

  /// Migrates the user document from [oldPhone] to [newPhone].
  ///
  /// Strategy (atomic-ish via batch):
  ///   1. Read the existing document under oldPhone.
  ///   2. Write it under newPhone (merging phone + updated_at).
  ///   3. Delete the oldPhone document.
  ///
  /// Callers must have already verified ownership of newPhone via OTP before
  /// calling this method.
  Future<void> migratePhone({
    required String oldPhone,
    required String newPhone,
  }) async {
    final oldRef = _db.collection('users').doc(oldPhone);
    final newRef = _db.collection('users').doc(newPhone);

    // 1. Read existing data so we carry over name, role, fcmTokens, etc.
    final snap = await oldRef.get();
    final existing = snap.data() ?? {};

    final batch = _db.batch();

    // 2. Create / merge new document, overriding phone and stamping updated_at.
    batch.set(
      newRef,
      {
        ...existing,
        'phone': newPhone,
        'updated_at': FieldValue.serverTimestamp(),
        // Wipe any FCM token — the device will re-register on next launch.
        'fcmToken': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );

    // 3. Remove old document.
    batch.delete(oldRef);

    await batch.commit();
  }

  // ── Read helpers ─────────────────────────────────────────────────────────

  /// Returns the stored display name for [phone], or empty string if absent.
  Future<String> fetchName(String phone) async {
    try {
      final doc = await _db.collection('users').doc(phone).get();
      return (doc.data()?['name'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }
}