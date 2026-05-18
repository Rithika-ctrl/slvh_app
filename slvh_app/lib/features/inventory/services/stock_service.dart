import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';
import '../../../core/utils/secure_logger.dart';

/// Exception for stock reservation failures
class StockReservationException implements Exception {
  final String message;
  final String? productId;
  final String? productName;
  final int? requiredQuantity;
  final int? availableQuantity;

  StockReservationException({
    required this.message,
    this.productId,
    this.productName,
    this.requiredQuantity,
    this.availableQuantity,
  });

  @override
  String toString() => message;
}

/// Service for atomic stock management using Firestore Transactions
/// Prevents overselling when multiple customers order simultaneously
/// 
/// Firestore Transactions guarantee:
/// 1. Atomic reads of all products in transaction
/// 2. Validation of stock levels
/// 3. Atomic writes of decremented stock
/// 4. Automatic rollback if validation fails
class StockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reserve stock atomically using Firestore transaction
  /// 
  /// Transaction flow:
  /// 1. Read all product documents
  /// 2. Validate stock >= requested quantity for each item
  /// 3. If valid: decrement all stock atomically
  /// 4. If invalid: roll back and throw exception
  /// 
  /// Returns: Map of productId -> new stock level after reservation
  /// Throws: StockReservationException if any item is out of stock
  Future<Map<String, int>> reserveStock(List<OrderItem> items) async {
    try {
      if (items.isEmpty) {
        return {};
      }

      // Use transaction for atomic read-validate-write
      final newStockLevels = <String, int>{};

      await _firestore.runTransaction((transaction) async {
        // STEP 1: Read all product documents
        final productRefs = <DocumentReference, String>{};
        for (final item in items) {
          final ref = _firestore.collection('products').doc(item.productId);
          productRefs[ref] = item.productId;
        }

        // Get all products in one read operation
        final snapshots = await Future.wait(
          productRefs.keys.map((ref) => transaction.get(ref)),
        );

        // STEP 2: Validate stock for all items
        final Map<DocumentReference, Map<String, dynamic>> updateMap = {};

        for (int i = 0; i < snapshots.length; i++) {
          final snapshot = snapshots[i];
          final ref = productRefs.keys.elementAt(i);
          final productId = productRefs[ref]!;

          // Find corresponding order item
          final orderItem =
              items.firstWhere((item) => item.productId == productId);

          if (!snapshot.exists) {
            throw StockReservationException(
              message: 'Product not found: $productId',
              productId: productId,
              productName: orderItem.productName,
            );
          }

          final data = snapshot.data() as Map<String, dynamic>;
          final currentStock = data['stock'] as int? ?? 0;
          final requiredQty = orderItem.quantity;

          // CHECK: Is stock sufficient?
          if (currentStock < requiredQty) {
            throw StockReservationException(
              message:
                  'Insufficient stock for ${orderItem.productName}. Required: $requiredQty, Available: $currentStock',
              productId: productId,
              productName: orderItem.productName,
              requiredQuantity: requiredQty,
              availableQuantity: currentStock,
            );
          }

          // Calculate new stock level
          final newStock = currentStock - requiredQty;
          newStockLevels[productId] = newStock;
          updateMap[ref] = {'stock': newStock};
        }

        // STEP 3: Atomically update all stock levels
        for (final entry in updateMap.entries) {
          final ref = entry.key as DocumentReference;
          final updates = entry.value as Map<String, dynamic>;
          transaction.update(ref, updates);
        }
      });

      AppLogger.debug(
          '✅ Stock reserved atomically for ${items.length} items: ${newStockLevels.toString()}');
      return newStockLevels;
    } catch (e) {
      if (e is StockReservationException) {
        AppLogger.debug('❌ Stock reservation failed: $e');
        rethrow;
      }
      throw StockReservationException(
        message: 'Stock reservation failed: ${e.toString()}',
      );
    }
  }

  /// Release stock back (for order cancellation or refund)
  /// Adds quantity back to product stock
  /// 
  /// Returns: new stock level after release
  Future<int> releaseStock(String productId, int quantity) async {
    try {
      if (quantity <= 0) {
        throw StockReservationException(
          message: 'Release quantity must be positive: $quantity',
          productId: productId,
        );
      }

      final productRef = _firestore.collection('products').doc(productId);

      late int newStock;

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(productRef);

        if (!snapshot.exists) {
          throw StockReservationException(
            message: 'Product not found: $productId',
            productId: productId,
          );
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final currentStock = data['stock'] as int? ?? 0;
        newStock = currentStock + quantity;

        transaction.update(productRef, {'stock': newStock});
      });

      AppLogger.debug('✅ Stock released: +$quantity for product $productId (new: $newStock)');
      return newStock;
    } catch (e) {
      if (e is StockReservationException) {
        AppLogger.debug('❌ Stock release failed: $e');
        rethrow;
      }
      throw StockReservationException(
        message: 'Stock release failed: ${e.toString()}',
        productId: productId,
      );
    }
  }

  /// Get current stock level for a product
  /// Quick read, not atomic (informational only)
  Future<int> getProductStock(String productId) async {
    try {
      final doc =
          await _firestore.collection('products').doc(productId).get();

      if (!doc.exists) {
        throw StockReservationException(
          message: 'Product not found: $productId',
          productId: productId,
        );
      }

      final data = doc.data() as Map<String, dynamic>;
      final stock = data['stock'] as int? ?? 0;

      return stock;
    } catch (e) {
      if (e is StockReservationException) {
        rethrow;
      }
      throw StockReservationException(
        message: 'Failed to fetch stock: ${e.toString()}',
        productId: productId,
      );
    }
  }

  /// Check if all products have sufficient stock (without reserving)
  /// Useful for pre-order validation UI
  /// 
  /// Returns: null if all stock available, or StockReservationException if not
  Future<StockReservationException?> validateStock(
      List<OrderItem> items) async {
    try {
      for (final item in items) {
        final stock = await getProductStock(item.productId);
        if (stock < item.quantity) {
          return StockReservationException(
            message:
                'Insufficient stock for ${item.productName}. Required: ${item.quantity}, Available: $stock',
            productId: item.productId,
            productName: item.productName,
            requiredQuantity: item.quantity,
            availableQuantity: stock,
          );
        }
      }
      return null; // All valid
    } catch (e) {
      return StockReservationException(
        message: 'Stock validation failed: ${e.toString()}',
      );
    }
  }
}


