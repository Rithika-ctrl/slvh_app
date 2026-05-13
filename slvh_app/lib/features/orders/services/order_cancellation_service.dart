import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';
import 'package:slvh_app/features/pickup_slots/services/slot_service.dart';
import 'package:slvh_app/features/settings/services/settings_service.dart';

/// Service for handling order cancellations
/// Allows customers to cancel orders with payment_verification_pending status
/// only if the order was placed within the configurable cancel_window_minutes.
/// Restores stock when order is cancelled.
class OrderCancellationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if an order can be cancelled by the customer.
  ///
  /// Rules:
  ///   1. Status must be [OrderStatus.paymentVerificationPending].
  ///   2. The order must have been created within the last
  ///      [cancelWindowMinutes] minutes.
  ///
  /// Pass [cancelWindowMinutes] from the loaded [ShopSettingsModel] so
  /// this check is always consistent with the current admin configuration.
  bool canCancelOrder(OrderModel order, {required int cancelWindowMinutes}) {
    if (order.status != OrderStatus.paymentVerificationPending) return false;

    final cutoff = order.createdAt.add(
      Duration(minutes: cancelWindowMinutes),
    );
    return DateTime.now().isBefore(cutoff);
  }

  /// Returns how many minutes the customer has left to cancel, or 0 if
  /// the window has already closed.  Useful for showing a countdown in the UI.
  int minutesLeftToCancel(OrderModel order, {required int cancelWindowMinutes}) {
    final cutoff = order.createdAt.add(Duration(minutes: cancelWindowMinutes));
    final remaining = cutoff.difference(DateTime.now()).inMinutes;
    return remaining < 0 ? 0 : remaining;
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

  /// Cancel an order (customer-initiated cancellation).
  ///
  /// [cancelWindowMinutes] must be passed from the current [ShopSettingsModel]
  /// so the time-window check uses the live admin configuration.
  ///
  /// - Updates order status to 'cancelled'
  /// - Restores stock for all items
  /// - Records cancellation reason
  /// Returns true if successful.
  Future<bool> cancelOrder({
    required String orderId,
    required OrderModel order,
    required String reason,
    required int cancelWindowMinutes,
  }) async {
    // Validate that order can be cancelled (status + time-window check)
    if (!canCancelOrder(order, cancelWindowMinutes: cancelWindowMinutes)) {
      final windowClosed = order.status == OrderStatus.paymentVerificationPending;
      if (windowClosed) {
        throw Exception(
          'Cancellation window has expired. Orders can only be cancelled '
          'within $cancelWindowMinutes minutes of placing them.',
        );
      }
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

      // 4. Cancel slot booking (decrements count) - outside batch as it uses its own transaction
      try {
        final pickupDate = DateTime.parse(order.pickupDate);
        await _slotService.cancelSlotBooking(pickupDate, order.pickupSlotId);
        print('✅ Slot booking cancelled: ${order.pickupSlotId}');
      } catch (e) {
        print('⚠️ Warning: Failed to cancel slot booking: $e');
        // We don't rethrow here because the order status and stock have already been updated
      }

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