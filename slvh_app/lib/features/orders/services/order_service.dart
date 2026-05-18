import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/inventory/services/stock_service.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';
import 'package:slvh_app/features/notifications/services/notification_service.dart';
import 'package:slvh_app/features/pickup_slots/services/slot_service.dart';
import '../../../core/utils/secure_logger.dart';

/// Service for managing orders (Firestore operations)
/// Uses Firestore Transactions to atomically reserve stock
/// Prevents overselling when multiple customers order simultaneously
class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StockService _stockService = StockService();
  final SlotService _slotService = SlotService();

  /// Create order with atomic stock reservation using Firestore Transaction
  /// 
  /// CRITICAL: Uses Firestore Transaction (not batch write) to:
  /// 1. Read all product stock levels
  /// 2. Validate sufficient stock for all items
  /// 3. Atomically decrement stock if valid
  /// 4. Create order only after stock is reserved
  /// 
  /// This prevents overselling when two customers order the last item simultaneously.
  /// Both customers can't complete orders - first wins, second gets StockReservationException.
  /// 
  /// Returns: Order ID if successful
  /// Throws: StockReservationException if stock insufficient
  Future<String> createOrder({
    required OrderModel order,
  }) async {
    try {
      AppLogger.debug('📦 Creating order with ${order.items.length} items...');

      // STEP 1: Reserve stock atomically using Firestore Transaction
      // This validates stock and decrements it in one atomic operation
      final newStockLevels = await _stockService.reserveStock(order.items);
      AppLogger.debug('✅ Stock reserved atomically: $newStockLevels');

      // STEP 2: Book pickup slot
      try {
        final pickupDate = DateTime.parse(order.pickupDate);
        final slotBooked = await _slotService.bookSlotById(
          pickupDate,
          order.pickupSlotId,
        );

        if (!slotBooked) {
          throw Exception(
            'Slot booking failed: pickup slot ${order.pickupSlotId} is full on ${order.pickupDate}',
          );
        }
        AppLogger.debug('✅ Pickup slot booked: ${order.pickupSlotId} on ${order.pickupDate}');
      } catch (e) {
        // NOTE: If slot booking fails, stock has already been reserved.
        // In a production environment, you might want a compensating action to restore stock,
        // or wrap both in a single large transaction.
        // For now, we throw and the UI will handle it.
        AppLogger.debug('❌ Slot booking failed: $e');
        rethrow;
      }

      // STEP 3: Create order document (stock and slot are already reserved)
      final orderRef = _firestore.collection('orders').doc();
      final orderId = orderRef.id;

      await orderRef.set(order.copyWith(id: orderId).toFirestore());

      AppLogger.debug('✅ Order created: $orderId');
      return orderId;
    } on StockReservationException {
      // Re-throw stock errors to be handled by UI
      AppLogger.debug('❌ Order creation failed: insufficient stock');
      rethrow;
    } catch (e) {
      AppLogger.debug('❌ Order creation failed: $e');
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
      // Fetch the order to get customer info
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      // Update order status in Firestore
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus.name,
        'updatedAt': DateTime.now(),
      });

      // Send notification to customer based on new status
      _sendOrderStatusNotification(
        orderId: orderId,
        customerId: order.customerId,
        newStatus: newStatus,
      );
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Send notification to customer when order status changes
  Future<void> _sendOrderStatusNotification({
    required String orderId,
    required String customerId,
    required OrderStatus newStatus,
  }) async {
    try {
      final notificationService = NotificationService();

      String title = '';
      String body = '';
      String? statusLabel;

      switch (newStatus) {
        case OrderStatus.confirmed:
          title = '✅ Order Confirmed';
          body = 'Your payment has been verified. Your order is confirmed!';
          statusLabel = 'Confirmed';
          break;
        case OrderStatus.preparing:
          title = '🍳 Preparing Your Order';
          body = 'We are preparing your order now.';
          statusLabel = 'Preparing';
          break;
        case OrderStatus.readyForPickup:
          title = '📦 Ready for Pickup!';
          body = 'Your order is ready! Come pick it up now.';
          statusLabel = 'Ready for Pickup';
          break;
        case OrderStatus.completed:
          title = '✓ Order Completed';
          body = 'Thank you for your order!';
          statusLabel = 'Completed';
          break;
        case OrderStatus.cancelled:
          title = '❌ Order Cancelled';
          body = 'Your order has been cancelled.';
          statusLabel = 'Cancelled';
          break;
        default:
          return; // Don't send notification for other statuses
      }

      // Save notification to Firestore
      await notificationService.saveNotification(
        userId: customerId,
        title: title,
        body: body,
        orderId: orderId,
        orderStatus: statusLabel,
        actionUrl: '/order/$orderId',
      );

      AppLogger.debug('✅ Notification sent to customer: $customerId');
    } catch (e) {
      AppLogger.debug('⚠️ Failed to send notification: $e');
      // Don't throw - order status update should succeed even if notification fails
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

        result[status.name] = querySnapshot.count ?? 0;
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


