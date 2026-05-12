import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';

/// Service for handling payment failures and retry logic
/// Manages draft orders and recovery from failed payment uploads
class PaymentRetryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save a draft order when payment upload fails
  /// Creates an order with status 'payment_retry_pending'
  /// Does NOT reduce stock yet - stock is reduced on retry success
  Future<String> saveDraftOrder({
    required OrderModel order,
    required String paymentReference,
  }) async {
    try {
      final draftOrder = order.copyWith(
        status: OrderStatus.paymentRetryPending,
        paymentReference: paymentReference,
        retryCount: 0,
        updatedAt: DateTime.now(),
      );

      // Create order document without reducing stock
      final orderRef = _firestore.collection('orders').doc();
      await orderRef.set(draftOrder.copyWith(id: orderRef.id).toFirestore());

      return orderRef.id;
    } catch (e) {
      throw Exception('Failed to save draft order: $e');
    }
  }

  /// Get all pending retry orders for a customer
  /// Returns orders with status 'payment_retry_pending'
  Future<List<OrderModel>> getPendingRetryOrders(
    String customerId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .where('status', isEqualTo: OrderStatus.paymentRetryPending.name)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch pending retry orders: $e');
    }
  }

  /// Retry payment upload for a draft order
  /// Increments retry count and updates lastRetryAt
  /// This is called when user taps "Retry Upload" button
  Future<void> markRetryAttempt(String orderId) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('orders').doc(orderId).update({
        'retryCount': FieldValue.increment(1),
        'lastRetryAt': now,
      });
    } catch (e) {
      throw Exception('Failed to mark retry attempt: $e');
    }
  }

  /// Recover a draft order to confirmed status
  /// Called when payment verification is successful after retry
  /// Reduces stock atomically
  Future<void> finalizeDraftOrder({
    required String orderId,
    required OrderModel order,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Update order status to paymentVerificationPending
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'status': OrderStatus.paymentVerificationPending.name,
        'updatedAt': DateTime.now(),
      });

      // 2. Reduce stock for each item
      for (final item in order.items) {
        final productRef =
            _firestore.collection('products').doc(item.productId);
        batch.update(productRef, {
          'stock': FieldValue.increment(-item.quantity),
        });
      }

      // 3. Commit batch atomically
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to finalize draft order: $e');
    }
  }

  /// Check if order is pending retry
  bool isPendingRetry(OrderModel order) {
    return order.status == OrderStatus.paymentRetryPending;
  }

  /// Get display message for retry state
  String getRetryMessage(OrderModel order) {
    final retries = order.retryCount;
    if (retries == 0) {
      return 'Payment successful, but upload failed. Tap Retry to complete order.';
    } else if (retries == 1) {
      return 'Upload failed on first attempt. Retrying...';
    } else {
      return 'Retry attempt $retries. Please check your connection.';
    }
  }

  /// Watch pending retry orders stream (real-time)
  Stream<List<OrderModel>> watchPendingRetryOrders(String customerId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .where('status', isEqualTo: OrderStatus.paymentRetryPending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Cancel a draft order (customer action or timeout)
  /// Restores stock if it was already reduced (safety check)
  Future<void> cancelDraftOrder({
    required String orderId,
    required OrderModel order,
  }) async {
    try {
      final batch = _firestore.batch();

      // Update order status to cancelled
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'status': OrderStatus.cancelled.name,
        'updatedAt': DateTime.now(),
      });

      // Restore stock (in case it was reduced - safety measure)
      for (final item in order.items) {
        final productRef =
            _firestore.collection('products').doc(item.productId);
        batch.update(productRef, {
          'stock': FieldValue.increment(item.quantity),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to cancel draft order: $e');
    }
  }

  /// Get time since last retry attempt (for rate limiting)
  Duration? getTimeSinceLastRetry(OrderModel order) {
    if (order.lastRetryAt == null) return null;
    return DateTime.now().difference(order.lastRetryAt!);
  }

  /// Check if enough time has passed since last retry (min 10 seconds)
  bool canRetryAgain(OrderModel order) {
    if (order.lastRetryAt == null) return true;
    final timeSinceLastRetry = getTimeSinceLastRetry(order)!;
    return timeSinceLastRetry.inSeconds >= 10;
  }
}
