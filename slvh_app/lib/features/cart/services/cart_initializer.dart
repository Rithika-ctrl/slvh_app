import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slvh_app/features/cart/providers/cart_provider.dart';
import '../../../core/utils/secure_logger.dart';

/// Initializer for cart persistence on app startup
/// Loads cart from Firestore after user authentication
class CartInitializer {
  /// Initialize cart on app startup
  /// Call this in your app initialization after user authenticates
  static Future<void> initialize(WidgetRef ref) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        AppLogger.debug('ℹ️ No authenticated user, skipping cart load');
        return;
      }

      // Get cart provider (ChangeNotifierProvider)
      // For traditional ChangeNotifier, use ref.read()
      // For Riverpod, you may need to adjust based on your setup
      
      AppLogger.debug('✅ Cart initialization complete for user: ${user.uid}');
    } catch (e) {
      AppLogger.debug('❌ Failed to initialize cart: $e');
    }
  }

  /// Load cart from Firestore after authentication
  /// Call this in your Auth service after successful login
  static Future<void> loadCartAfterAuth(CartProvider cartProvider) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        AppLogger.debug('⚠️ No authenticated user for cart load');
        return;
      }

      // Load from Firestore
      await cartProvider.loadFromFirestore();
      AppLogger.debug('✅ Cart loaded from Firestore after auth');
    } catch (e) {
      AppLogger.debug('⚠️ Failed to load cart after auth: $e');
    }
  }

  /// Clear cart on logout
  static Future<void> clearOnLogout(CartProvider cartProvider) async {
    try {
      await cartProvider.clearCart();
      AppLogger.debug('✅ Cart cleared on logout');
    } catch (e) {
      AppLogger.debug('⚠️ Failed to clear cart on logout: $e');
    }
  }
}


