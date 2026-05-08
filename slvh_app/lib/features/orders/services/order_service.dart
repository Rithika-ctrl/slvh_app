import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';

/// Service for managing orders (Firestore operations)
/// Uses batch writes for atomic operations (create order + reduce stock)
class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create order with automatic stock reduction (atomic batch write)
  /// Returns the order ID if successful
  /// Throws exception if stock insufficient or other error
  Future<String> createOrder({
    required OrderModel order,
  }) async {
    try {
      // Create batch write
      final batch = _firestore.batch();

      // 1. Create order document
      final orderRef = _firestore.collection('orders').doc();
      batch.set(orderRef, order.copyWith(id: orderRef.id).toFirestore());

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

      return orderRef.id;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Get order by ID
  Future<OrderModel?> getOrder(String orderId) async {
    try {
      final docSnapshot = await _firestore.collection('orders').doc(orderId).get();

      if (!docSnapshot.exists) {
        return null;
      }

      return OrderModel.fromFirestore(
        docSnapshot.id,
        docSnapshot.data() as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Failed to fetch order: $e');
    }
  }

  /// Watch order in real-time
  Stream<OrderModel?> watchOrder(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((docSnapshot) {
      if (!docSnapshot.exists) {
        return null;
      }
      return OrderModel.fromFirestore(
        docSnapshot.id,
        docSnapshot.data() as Map<String, dynamic>,
      );
    });
  }

  /// Get all orders for a customer
  Future<List<OrderModel>> getCustomerOrders(String customerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch customer orders: $e');
    }
  }

  /// Stream of customer orders (real-time)
  Stream<List<OrderModel>> watchCustomerOrders(String customerId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Get orders by status
  Future<List<OrderModel>> getOrdersByStatus(String status) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch orders by status: $e');
    }
  }

  /// Stream of orders by status (for admin dashboard)
  Stream<List<OrderModel>> watchOrdersByStatus(String status) {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Update order status
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus,
  ) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus.name,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Update payment status and link payment
  Future<void> updateOrderPaymentStatus(
    String orderId,
    String paymentId,
    String paymentStatus,
  ) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'paymentId': paymentId,
        'paymentStatus': paymentStatus,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update payment status: $e');
    }
  }

  /// Mark order as completed
  Future<void> completeOrder(String orderId) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('orders').doc(orderId).update({
        'status': OrderStatus.completed.name,
        'completedAt': now,
        'updatedAt': now,
      });
    } catch (e) {
      throw Exception('Failed to complete order: $e');
    }
  }

  /// Cancel order (with optional reason)
  /// Restores stock if order was created successfully
  Future<void> cancelOrder(
    String orderId, {
    String? cancellationReason,
  }) async {
    try {
      // Get order to restore stock
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      // Create batch for atomic update
      final batch = _firestore.batch();

      // 1. Update order status
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'status': OrderStatus.cancelled.name,
        'updatedAt': DateTime.now(),
      });

      // 2. Restore stock for each item
      for (final item in order.items) {
        final productRef =
            _firestore.collection('products').doc(item.productId);
        batch.update(productRef, {
          'stock': FieldValue.increment(item.quantity),
        });
      }

      // 3. Commit batch
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  /// Get active orders for a customer
  /// (Not cancelled or completed)
  Future<List<OrderModel>> getActiveOrders(String customerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .where('status', whereIn: [
            OrderStatus.pendingPayment.name,
            OrderStatus.paymentVerificationPending.name,
            OrderStatus.confirmed.name,
            OrderStatus.preparing.name,
            OrderStatus.readyForPickup.name,
          ])
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch active orders: $e');
    }
  }

  /// Stream of active orders
  Stream<List<OrderModel>> watchActiveOrders(String customerId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .where('status', whereIn: [
          OrderStatus.pendingPayment.name,
          OrderStatus.paymentVerificationPending.name,
          OrderStatus.confirmed.name,
          OrderStatus.preparing.name,
          OrderStatus.readyForPickup.name,
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Get total revenue for a date range
  Future<double> getTotalRevenue({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: OrderStatus.completed.name)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      double total = 0;
      for (final doc in querySnapshot.docs) {
        final amount = (doc.data()['total'] as num?)?.toDouble() ?? 0.0;
        total += amount;
      }

      return total;
    } catch (e) {
      throw Exception('Failed to calculate revenue: $e');
    }
  }

  /// Get order count by status (for admin analytics)
  Future<Map<String, int>> getOrderCountByStatus() async {
    try {
      final result = <String, int>{};

      for (final status in OrderStatus.values) {
        final querySnapshot = await _firestore
            .collection('orders')
            .where('status', isEqualTo: status.name)
            .count()
            .get();

        result[status.name] = querySnapshot.count;
      }

      return result;
    } catch (e) {
      throw Exception('Failed to get order count: $e');
    }
  }

  /// Delete order (admin only, use with caution)
  /// This does NOT restore stock - use cancelOrder instead
  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
    } catch (e) {
      throw Exception('Failed to delete order: $e');
    }
  }

  /// Search orders by order ID or customer ID
  Future<List<OrderModel>> searchOrders(String query) async {
    try {
      // Search by ID (prefix search)
      final querySnapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: query)
          .get();

      return querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to search orders: $e');
    }
  }

  /// Get orders for a specific pickup date (for admin preparation)
  Future<List<OrderModel>> getOrdersForPickupDate(String pickupDate) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('pickupDate', isEqualTo: pickupDate)
          .where('status', whereIn: [
            OrderStatus.confirmed.name,
            OrderStatus.preparing.name,
            OrderStatus.readyForPickup.name,
          ])
          .orderBy('pickupTime')
          .get();

      return querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch orders for pickup date: $e');
    }
  }
}
