import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/payments/models/payment_model.dart';
import 'package:slvh_app/features/notifications/services/notification_service.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';

/// Service for handling payment rejection flow
/// When vendor rejects payment screenshot, this handles:
/// - Updating payment status to rejected
/// - Storing rejection reason
/// - Notifying customer
/// - Providing refund instructions
class PaymentRejectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Reject a payment with reason
  /// Called by admin/vendor when rejecting payment screenshot
  /// 
  /// Parameters:
  ///   paymentId: Payment document ID to reject
  ///   orderId: Associated order ID
  ///   rejectionReason: Why the payment was rejected
  ///   customerPhone: Customer phone number for notification
  /// 
  /// Effects:
  ///   1. Updates payment.status = 'rejected'
  ///   2. Stores payment.rejectionReason
  ///   3. Updates order.status = 'paymentRejected'
  ///   4. Records rejection timestamp
  ///   5. Sends FCM notification to customer
  /// 
  /// Returns: Updated PaymentModel
  Future<PaymentModel> rejectPayment({
    required String paymentId,
    required String orderId,
    required String rejectionReason,
    required String customerPhone,
  }) async {
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      // Update payment
      final paymentRef = _firestore.collection('payments').doc(paymentId);
      batch.update(paymentRef, {
        'status': PaymentStatus.rejected.name,
        'rejectionReason': rejectionReason,
        'updatedAt': now,
      });

      // Update order
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'status': OrderStatus.paymentRejected.name,
        'updatedAt': now,
      });

      // Commit all changes atomically
      await batch.commit();

      // Get updated payment
      final updatedPayment = await _firestore
          .collection('payments')
          .doc(paymentId)
          .get()
          .then((doc) => PaymentModel.fromFirestore(doc.id, doc.data() ?? {}));

      // Send notification to customer
      await _notifyCustomerOfRejection(
        customerPhone: customerPhone,
        orderId: orderId,
        rejectionReason: rejectionReason,
      );

      return updatedPayment;
    } catch (e) {
      throw Exception('Failed to reject payment: $e');
    }
  }

  /// Send notification to customer about payment rejection
  /// Includes refund instructions
  Future<void> _notifyCustomerOfRejection({
    required String customerPhone,
    required String orderId,
    required String rejectionReason,
  }) async {
    try {
      final title = '❌ Payment Rejected';
      final body = 'Your payment for order $orderId was rejected: $rejectionReason. '
          'Tap for refund instructions.';

      // Send local notification (when app is open or recently closed)
      await _notificationService.sendLocalNotification(
        title: title,
        body: body,
        orderId: orderId,
        status: OrderStatus.paymentRejected.name,
      );

      // Save to notification history
      // Note: In production, get userId from auth, not phone
      await _notificationService.saveNotification(
        userId: customerPhone, // Using phone as identifier
        title: title,
        body: body,
        orderId: orderId,
        orderStatus: OrderStatus.paymentRejected.name,
        actionUrl: '/orders/$orderId/refund',
      );

      print('✅ Customer notified about payment rejection');
    } catch (e) {
      print('⚠️ Failed to notify customer: $e');
      // Don't throw - notification failure shouldn't block rejection
    }
  }

  /// Get rejection details for refund instruction screen
  Future<PaymentModel?> getRejectedPaymentDetails(String paymentId) async {
    try {
      final doc =
          await _firestore.collection('payments').doc(paymentId).get();

      if (!doc.exists) {
        return null;
      }

      return PaymentModel.fromFirestore(doc.id, doc.data() ?? {});
    } catch (e) {
      throw Exception('Failed to fetch payment details: $e');
    }
  }

  /// Get rejected payment by order ID
  Future<PaymentModel?> getRejectedPaymentByOrderId(String orderId) async {
    try {
      final query = await _firestore
          .collection('payments')
          .where('orderId', isEqualTo: orderId)
          .where('status', isEqualTo: PaymentStatus.rejected.name)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final doc = query.docs.first;
      return PaymentModel.fromFirestore(doc.id, doc.data());
    } catch (e) {
      throw Exception('Failed to fetch rejected payment: $e');
    }
  }

  /// Watch for rejected payments (real-time for order detail screen)
  Stream<PaymentModel?> watchRejectedPaymentByOrderId(String orderId) {
    return _firestore
        .collection('payments')
        .where('orderId', isEqualTo: orderId)
        .where('status', isEqualTo: PaymentStatus.rejected.name)
        .limit(1)
        .snapshots()
        .map((query) {
      if (query.docs.isEmpty) {
        return null;
      }
      final doc = query.docs.first;
      return PaymentModel.fromFirestore(doc.id, doc.data());
    });
  }

  /// Get shop contact info for refund instructions
  Future<Map<String, String>> getShopContactInfo() async {
    try {
      final doc = await _firestore.collection('app_settings').doc('contact').get();

      if (!doc.exists) {
        return {
          'phone': '+91-XXXXXXXXXX',
          'email': 'support@smartshop.com',
          'whatsapp': '+91-XXXXXXXXXX',
        };
      }

      return {
        'phone': doc['phone'] as String? ?? '+91-XXXXXXXXXX',
        'email': doc['email'] as String? ?? 'support@smartshop.com',
        'whatsapp': doc['whatsapp'] as String? ?? '+91-XXXXXXXXXX',
      };
    } catch (e) {
      print('⚠️ Failed to fetch shop contact info: $e');
      return {
        'phone': '+91-XXXXXXXXXX',
        'email': 'support@smartshop.com',
        'whatsapp': '+91-XXXXXXXXXX',
      };
    }
  }

  /// Check if customer can retry payment
  /// (after rejection, they should be able to submit new payment)
  bool canRetryPayment(PaymentModel payment) {
    return payment.isRejected;
  }

  /// Get refund process instructions
  String getRefundInstructions(String rejectionReason) {
    return '''
Payment Refund Process
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Your payment was rejected for the following reason:
"$rejectionReason"

📋 Refund Process:
1. Your payment will be refunded to your original bank account/UPI
2. Refunds typically process within 5-7 business days
3. You will receive a WhatsApp notification once refunded

⏰ What to do now:
• Contact our team if you don't receive refund within 7 days
• You can retry payment with the correct details
• Choose "Retry Payment" below to submit payment again

💬 Need Help?
Contact us via WhatsApp, Phone, or Email for assistance
''';
  }
}
