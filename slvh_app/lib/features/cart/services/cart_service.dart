import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:slvh_app/features/cart/models/cart_item_model.dart';

/// Service for persisting cart to Firestore
/// Saves cart data to users/{uid}/cart document
/// Structure: { items: [...], updated_at: timestamp }
class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save cart items to Firestore
  /// Called on every cart change: add, remove, update quantity, etc.
  Future<void> saveCart(List<CartItemModel> items) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('⚠️ User not authenticated, skipping Firestore cart save');
        return;
      }

      await _firestore.collection('users').doc(userId).collection('cart').doc('data').set({
        'items': items.map((item) => item.toJson()).toList(),
        'updated_at': DateTime.now(),
        'item_count': items.length,
        'total_units': items.fold<int>(0, (sum, item) => sum + item.quantity),
      });

      print('✅ Cart saved to Firestore (${items.length} items)');
    } catch (e) {
      print('❌ Failed to save cart to Firestore: $e');
      // Don't throw - local cart should still work
    }
  }

  /// Load cart items from Firestore
  /// Called on app startup after authentication
  Future<List<CartItemModel>> loadCart() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('⚠️ User not authenticated, skipping Firestore cart load');
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
        return [];
      }

      final data = doc.data() as Map<String, dynamic>;
      final itemsList = data['items'] as List<dynamic>? ?? [];

      return itemsList
          .map((item) => CartItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  /// Clear cart from Firestore
  /// Called when user checks out or manually clears cart
  Future<void> clearCart() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

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

  /// Get cart summary (for display without loading full items)
  Future<Map<String, dynamic>?> getCartSummary() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

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
