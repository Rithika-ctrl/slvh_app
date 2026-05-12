import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';

/// Service for handling order cancellations
/// Allows customers to cancel orders with payment_verification_pending status
/// Restores stock when order is cancelled
class OrderCancellationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if an order can be cancelled by the customer
  /// Only orders with status 'paymentVerificationPending' can be cancelled
  bool canCancelOrder(OrderModel order) {
    return order.status == OrderStatus.paymentVerificationPending;
  }

  /// Get cancellation reason options
  static const List<String> cancellationReasons = [
    'Changed my mind',
    'Found better price elsewhere',
    'Delivery/pickup time not convenient',
    'Found required item elsewhere',
    'Quality concerns',
    'No longer needed',
    'Order placed by mistake',
    'Other',
  ];

  /// Cancel an order (customer-initiated cancellation)
  /// - Updates order status to 'cancelled'
  /// - Restores stock for all items
  /// - Records cancellation reason
  /// Returns true if successful
  Future<bool> cancelOrder({
    required String orderId,
    required OrderModel order,
    required String reason,
  }) async {
    // Validate that order can be cancelled
    if (!canCancelOrder(order)) {
      throw Exception(
        'Order cannot be cancelled. Only pending payment verification orders can be cancelled.',
      );
    }

    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      // 1. Update order status to cancelled
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'status': OrderStatus.cancelled.name,
        'cancellationReason': reason,
        'cancelledAt': now,
        'updatedAt': now,
      });

      // 2. Restore stock for each item
      for (final item in order.items) {
        final productRef =
            _firestore.collection('products').doc(item.productId);
        batch.update(productRef, {
          'stock': FieldValue.increment(item.quantity),
        });
      }

      // 3. Commit batch atomically
      await batch.commit();

      return true;
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  /// Get cancellation details for an order
  Future<Map<String, dynamic>?> getCancellationDetails(
    String orderId,
  ) async {
    try {
      final docSnapshot =
          await _firestore.collection('orders').doc(orderId).get();

      if (!docSnapshot.exists) {
        return null;
      }

      final data = docSnapshot.data()!;
      if (data['status'] != OrderStatus.cancelled.name) {
        return null;
      }

      return {
        'reason': data['cancellationReason'],
        'cancelledAt': (data['cancelledAt'] as Timestamp?)?.toDate(),
      };
    } catch (e) {
      throw Exception('Failed to get cancellation details: $e');
    }
  }

  /// Get cancellation reason display text
  String getCancellationReasonDisplay(String reason) {
    // In future, could translate or format reasons
    return reason;
  }

  /// Calculate refund amount (currently full refund)
  double getRefundAmount(OrderModel order) {
    // Full refund of order total
    return order.total;
  }

  /// Check if order was cancelled by customer
  bool wasCancelledByCustomer(OrderModel order) {
    return order.status == OrderStatus.cancelled;
  }

  /// Get display message for cancelled order
  String getCancellationMessage(OrderModel order) {
    if (order.status == OrderStatus.cancelled) {
      return 'This order was cancelled. A refund of ₹${order.total.toStringAsFixed(2)} has been processed.';
    }
    return '';
  }

  /// Watch cancellation status of an order
  Stream<bool> watchOrderCancellation(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists) return false;
        final data = snapshot.data()!;
        return data['status'] == OrderStatus.cancelled.name;
      },
    );
  }

  /// Get orders cancelled by customer (for analytics)
  Future<List<OrderModel>> getCustomerCancelledOrders(
    String customerId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .where('status', isEqualTo: OrderStatus.cancelled.name)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch cancelled orders: $e');
    }
  }
}
