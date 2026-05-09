import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/products/models/product_model.dart';

/// Service for managing inventory and stock levels
class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String lowStockThresholdKey = 'lowStockThreshold';
  static const int defaultLowStockThreshold = 10;

  /// Get all products with current stock levels
  Future<List<ProductModel>> getAllProductsWithStock() async {
    try {
      final querySnapshot = await _firestore.collection('products').get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch products with stock: $e');
    }
  }

  /// Stream all products with real-time stock updates
  Stream<List<ProductModel>> watchAllProductsWithStock() {
    return _firestore
        .collection('products')
        .orderBy('name')
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Get low stock threshold
  Future<int> getLowStockThreshold() async {
    try {
      final doc = await _firestore
          .collection('app_settings')
          .doc('inventory')
          .get();

      if (doc.exists) {
        return doc.data()?[lowStockThresholdKey] ?? defaultLowStockThreshold;
      }
      return defaultLowStockThreshold;
    } catch (e) {
      return defaultLowStockThreshold;
    }
  }

  /// Set low stock threshold
  Future<void> setLowStockThreshold(int threshold) async {
    try {
      await _firestore
          .collection('app_settings')
          .doc('inventory')
          .set({lowStockThresholdKey: threshold}, SetOptions(merge: true));

      print('✅ Low stock threshold set to: $threshold');
    } catch (e) {
      throw Exception('Failed to set low stock threshold: $e');
    }
  }

  /// Adjust stock manually (admin only)
  /// Logs all adjustments for audit trail
  Future<void> adjustStock({
    required String productId,
    required int quantityChange, // Positive to add, negative to reduce
    required String reason, // Why stock was adjusted
    required String adminId,
  }) async {
    try {
      // Start transaction for atomic update
      await _firestore.runTransaction((transaction) async {
        // Get current product
        final productRef = _firestore.collection('products').doc(productId);
        final productDoc = await transaction.get(productRef);

        if (!productDoc.exists) {
          throw Exception('Product not found');
        }

        final currentStock = productDoc.data()?['stock'] as int? ?? 0;
        final newStock = currentStock + quantityChange;

        // Prevent stock from going negative
        if (newStock < 0) {
          throw Exception(
            'Cannot reduce stock below 0. Current: $currentStock, Requested reduction: ${quantityChange.abs()}',
          );
        }

        // Update product stock
        transaction.update(productRef, {'stock': newStock});
      });

      // Log adjustment to audit collection
      await _firestore.collection('stock_adjustments').add({
        'productId': productId,
        'quantityChange': quantityChange,
        'reason': reason,
        'adminId': adminId,
        'timestamp': DateTime.now(),
      });

      print('✅ Stock adjusted for product $productId: $quantityChange units');
    } catch (e) {
      throw Exception('Failed to adjust stock: $e');
    }
  }

  /// Check if product is low on stock
  Future<bool> isLowStock(String productId) async {
    try {
      final threshold = await getLowStockThreshold();
      final doc =
          await _firestore.collection('products').doc(productId).get();

      if (!doc.exists) return false;

      final stock = doc.data()?['stock'] as int? ?? 0;
      return stock <= threshold;
    } catch (e) {
      print('Error checking low stock: $e');
      return false;
    }
  }

  /// Get all low stock products
  Future<List<ProductModel>> getLowStockProducts() async {
    try {
      final threshold = await getLowStockThreshold();
      final querySnapshot = await _firestore
          .collection('products')
          .where('stock', isLessThanOrEqualTo: threshold)
          .orderBy('stock')
          .get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch low stock products: $e');
    }
  }

  /// Stream low stock products in real-time
  Stream<List<ProductModel>> watchLowStockProducts() async* {
    try {
      final threshold = await getLowStockThreshold();

      yield* _firestore
          .collection('products')
          .where('stock', isLessThanOrEqualTo: threshold)
          .orderBy('stock')
          .snapshots()
          .map((querySnapshot) {
        return querySnapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
            .toList();
      });
    } catch (e) {
      print('Error watching low stock products: $e');
      yield [];
    }
  }

  /// Get out of stock products (stock = 0)
  Future<List<ProductModel>> getOutOfStockProducts() async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('stock', isEqualTo: 0)
          .get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch out of stock products: $e');
    }
  }

  /// Get stock adjustment history for a product
  Future<List<Map<String, dynamic>>> getStockAdjustmentHistory(
    String productId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('stock_adjustments')
          .where('productId', isEqualTo: productId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to fetch stock adjustment history: $e');
    }
  }

  /// Stream stock adjustment history (real-time)
  Stream<List<Map<String, dynamic>>> watchStockAdjustmentHistory(
    String productId,
  ) {
    return _firestore
        .collection('stock_adjustments')
        .where('productId', isEqualTo: productId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  /// Get inventory statistics
  Future<Map<String, dynamic>> getInventoryStats() async {
    try {
      final allProducts = await getAllProductsWithStock();
      final threshold = await getLowStockThreshold();

      int totalStock = 0;
      int lowStockCount = 0;
      int outOfStockCount = 0;
      int okStockCount = 0;

      for (final product in allProducts) {
        totalStock += product.stock;

        if (product.stock == 0) {
          outOfStockCount++;
        } else if (product.stock <= threshold) {
          lowStockCount++;
        } else {
          okStockCount++;
        }
      }

      return {
        'totalProducts': allProducts.length,
        'totalStock': totalStock,
        'okStock': okStockCount,
        'lowStock': lowStockCount,
        'outOfStock': outOfStockCount,
        'lowStockThreshold': threshold,
      };
    } catch (e) {
      throw Exception('Failed to get inventory statistics: $e');
    }
  }

  /// Stream inventory statistics (real-time)
  Stream<Map<String, dynamic>> watchInventoryStats() async* {
    try {
      final threshold = await getLowStockThreshold();

      yield* _firestore
          .collection('products')
          .snapshots()
          .asyncMap((querySnapshot) async {
        int totalStock = 0;
        int lowStockCount = 0;
        int outOfStockCount = 0;
        int okStockCount = 0;

        for (final doc in querySnapshot.docs) {
          final product = ProductModel.fromFirestore(doc.id, doc.data());
          totalStock += product.stock;

          if (product.stock == 0) {
            outOfStockCount++;
          } else if (product.stock <= threshold) {
            lowStockCount++;
          } else {
            okStockCount++;
          }
        }

        return {
          'totalProducts': querySnapshot.docs.length,
          'totalStock': totalStock,
          'okStock': okStockCount,
          'lowStock': lowStockCount,
          'outOfStock': outOfStockCount,
          'lowStockThreshold': threshold,
        };
      });
    } catch (e) {
      print('Error watching inventory stats: $e');
      yield {};
    }
  }
}
