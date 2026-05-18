import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/secure_logger.dart';

/// Service for monitoring product stock levels in real-time
/// Tracks which cart items go out of stock and notifies listeners
class OutOfStockHandler {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Maps product ID to subscription and current stock status
  final Map<String, StreamSubscription<DocumentSnapshot>> _stockListeners = {};
  final Map<String, int> _currentStock = {};
  
  // Callback when stock status changes
  late Function(String productId, int newStock)? _onStockChanged;

  /// Initialize stock monitoring for cart items
  /// Tracks each product's stock level in real-time
  Future<void> initializeStockMonitoring({
    required List<String> productIds,
    required Function(String productId, int newStock) onStockChanged,
  }) async {
    _onStockChanged = onStockChanged;

    // Clean up old listeners first
    _clearAllListeners();

    // Set up new listeners for each product
    for (final productId in productIds) {
      _setupStockListener(productId);
    }

    AppLogger.debug('✅ Stock monitoring initialized for ${productIds.length} products');
  }

  /// Set up real-time listener for a single product's stock
  Future<void> _setupStockListener(String productId) async {
    try {
      // First, get initial stock
      final doc = await _firestore.collection('products').doc(productId).get();
      
      if (doc.exists) {
        final stock = doc.data()?['stock'] as int? ?? 0;
        _currentStock[productId] = stock;
        AppLogger.debug('📦 Initial stock for $productId: $stock units');
      }

      // Then set up real-time listener
      final subscription = _firestore
          .collection('products')
          .doc(productId)
          .snapshots()
          .listen(
            (docSnapshot) {
              if (docSnapshot.exists) {
                final newStock = docSnapshot.data()?['stock'] as int? ?? 0;
                final oldStock = _currentStock[productId] ?? 0;

                // Only notify if stock actually changed
                if (newStock != oldStock) {
                  _currentStock[productId] = newStock;
                  AppLogger.debug('📊 Stock changed for $productId: $oldStock → $newStock');
                  
                  // Call the callback
                  _onStockChanged?.call(productId, newStock);
                }
              }
            },
            onError: (error) {
              AppLogger.debug('❌ Error listening to stock for $productId: $error');
            },
          );

      // Store subscription for cleanup
      _stockListeners[productId] = subscription;
    } catch (e) {
      AppLogger.debug('❌ Failed to set up stock listener for $productId: $e');
    }
  }

  /// Get current stock for a product
  int getStock(String productId) {
    return _currentStock[productId] ?? 0;
  }

  /// Check if product is out of stock
  bool isOutOfStock(String productId) {
    return getStock(productId) == 0;
  }

  /// Check if product is low on stock
  bool isLowStock(String productId, {int threshold = 5}) {
    final stock = getStock(productId);
    return stock > 0 && stock <= threshold;
  }

  /// Remove listener for a specific product
  void removeListener(String productId) {
    _stockListeners[productId]?.cancel();
    _stockListeners.remove(productId);
    _currentStock.remove(productId);
  }

  /// Clear all stock listeners and tracking data
  void _clearAllListeners() {
    for (final subscription in _stockListeners.values) {
      subscription.cancel();
    }
    _stockListeners.clear();
    _currentStock.clear();
  }

  /// Dispose the handler (call when cart screen is disposed)
  void dispose() {
    _clearAllListeners();
    _onStockChanged = null;
    AppLogger.debug('✅ OutOfStockHandler disposed');
  }
}

