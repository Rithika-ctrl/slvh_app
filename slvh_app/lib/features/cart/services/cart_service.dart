import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:slvh_app/features/cart/models/cart_item_model.dart';
import 'package:slvh_app/connectivity/connectivity_service.dart';
import 'package:slvh_app/connectivity/pending_write_queue.dart';

/// Service for persisting cart to Firestore
/// Saves cart data to users/{uid}/cart document
/// Structure: { items: [...], updated_at: timestamp }
///
/// Feature 11: Offline / No Internet Handling
/// saveCart() now checks connectivity first:
///   • Online  → writes directly to Firestore (existing behaviour)
///   • Offline → enqueues write to Hive; syncs automatically when online
class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const _uuid = Uuid();

  // ── INIT (call once from app startup to register the executor) ───────────

  /// Register this service's Firestore writer with the pending-write queue.
  /// Called once from main() after PendingWriteQueue.initialize().
  static void registerQueueExecutor() {
    PendingWriteQueue.instance;
    // Executor is injected per-write in _enqueueCartSave so it has
    // access to the live Firestore instance. Nothing needed here —
    // the queue calls back into _executeWrite() via the closure stored
    // in each PendingWrite's data under the key '_executor_type'.
    //
    // The real wiring is done in PendingWriteQueue.initialize() in main.dart
    // by passing the CartService-aware executor.
  }

  // ── SAVE (offline-aware) ─────────────────────────────────────────────────

  /// Save cart items — works online AND offline.
  ///
  /// Online:  writes straight to Firestore (original behaviour, unchanged)
  /// Offline: serialises the cart into a PendingWrite and stores it in Hive.
  ///          The queue auto-replays when connectivity is restored.
  Future<void> saveCart(List<CartItemModel> items) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('⚠️ User not authenticated, skipping cart save');
      return;
    }

    final payload = {
      'items': items.map((item) => item.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
      'item_count': items.length,
      'total_units': items.fold<int>(0, (sum, item) => sum + item.quantity),
    };

    if (ConnectivityService.instance.isOnline) {
      // ── Online path (unchanged) ──────────────────────────────────────
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('cart')
            .doc('data')
            .set(payload);
        print('✅ Cart saved to Firestore (${items.length} items)');
      } catch (e) {
        print('❌ Failed to save cart to Firestore: $e');
        // Don't throw — local cart (SharedPreferences) still works
      }
    } else {
      // ── Offline path — queue for later ──────────────────────────────
      await PendingWriteQueue.instance.enqueue(PendingWrite(
        id: _uuid.v4(),
        collection: 'users',
        docId: userId,
        subCollection: 'cart',
        subDocId: 'data',
        data: payload,
        operation: PendingWriteOp.set,
        createdAt: DateTime.now(),
        merge: false, // overwrite the cart, not merge
      ));
      print('📥 Cart queued offline (${items.length} items) — will sync when online');
    }
  }

  // ── LOAD ─────────────────────────────────────────────────────────────────

  /// Load cart items from Firestore
  /// Called on app startup after authentication
  Future<List<CartItemModel>> loadCart() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('⚠️ User not authenticated, skipping Firestore cart load');
        return [];
      }

      if (!ConnectivityService.instance.isOnline) {
        // Offline — return empty; CartProvider will fall back to
        // SharedPreferences which already has the local copy.
        print('📴 Offline — skipping Firestore cart load, using local cache');
        return [];
      }

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc('data')
          .get();

      if (!doc.exists) {
        print('ℹ️ No saved cart found in Firestore');
        return [];
      }

      final data = doc.data() as Map<String, dynamic>;
      final itemsList = data['items'] as List<dynamic>? ?? [];

      final items = itemsList
          .map((item) => CartItemModel.fromJson(item as Map<String, dynamic>))
          .toList();

      print('✅ Cart loaded from Firestore (${items.length} items)');
      return items;
    } catch (e) {
      print('❌ Failed to load cart from Firestore: $e');
      return [];
    }
  }

  // ── WATCH ────────────────────────────────────────────────────────────────

  /// Watch cart in real-time (for multi-device sync)
  /// Returns a stream of cart items
  Stream<List<CartItemModel>> watchCart() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc('data')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return <CartItemModel>[];
      }

      final data = doc.data() as Map<String, dynamic>;
      final itemsList = data['items'] as List<dynamic>? ?? [];

      return itemsList
          .map((item) => CartItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  // ── CLEAR ────────────────────────────────────────────────────────────────

  /// Clear cart from Firestore
  /// Called when user checks out or manually clears cart
  Future<void> clearCart() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      if (!ConnectivityService.instance.isOnline) {
        // Queue a delete — represented as a set with empty items
        await PendingWriteQueue.instance.enqueue(PendingWrite(
          id: _uuid.v4(),
          collection: 'users',
          docId: userId,
          subCollection: 'cart',
          subDocId: 'data',
          data: {'items': [], 'updated_at': DateTime.now().toIso8601String()},
          operation: PendingWriteOp.set,
          createdAt: DateTime.now(),
          merge: false,
        ));
        print('📥 Cart clear queued offline — will sync when online');
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc('data')
          .delete();

      print('✅ Cart cleared from Firestore');
    } catch (e) {
      print('❌ Failed to clear cart from Firestore: $e');
    }
  }

  // ── SUMMARY ──────────────────────────────────────────────────────────────

  /// Get cart summary (for display without loading full items)
  Future<Map<String, dynamic>?> getCartSummary() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      if (!ConnectivityService.instance.isOnline) return null;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc('data')
          .get();

      if (!doc.exists) return null;

      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      print('⚠️ Failed to get cart summary: $e');
      return null;
    }
  }
}

// ── Firestore executor (called by PendingWriteQueue on reconnect) ─────────────

/// Registered in main.dart as the queue's executor.
/// Performs the actual Firestore write for any queued cart operation.
Future<void> cartQueueExecutor(PendingWrite write) async {
  final firestore = FirebaseFirestore.instance;

  DocumentReference ref;

  if (write.subCollection != null && write.subDocId != null) {
    ref = firestore
        .collection(write.collection)
        .doc(write.docId)
        .collection(write.subCollection!)
        .doc(write.subDocId!);
  } else {
    ref = firestore.collection(write.collection).doc(write.docId);
  }

  switch (write.operation) {
    case PendingWriteOp.set:
      await ref.set(
        write.data,
        write.merge ? SetOptions(merge: true) : null,
      );
      break;
    case PendingWriteOp.update:
      await ref.update(write.data);
      break;
    case PendingWriteOp.delete:
      await ref.delete();
      break;
  }
}
