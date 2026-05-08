import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:slvh_app/features/payments/models/payment_model.dart';
import 'package:slvh_app/features/pickup_slots/models/slot_model.dart';

/// Service for managing payment operations (Firestore + Firebase Storage)
class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get shop settings including UPI ID
  Future<ShopSettingsModel> getShopSettings() async {
    try {
      final docSnapshot =
          await _firestore.collection('settings').doc('default').get();

      if (!docSnapshot.exists) {
        throw Exception('Shop settings not found');
      }

      return ShopSettingsModel.fromFirestore(
        docSnapshot.id,
        docSnapshot.data() as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Failed to fetch shop settings: $e');
    }
  }

  /// Watch shop settings in real-time
  Stream<ShopSettingsModel> watchShopSettings() {
    return _firestore
        .collection('settings')
        .doc('default')
        .snapshots()
        .map((docSnapshot) {
      if (!docSnapshot.exists) {
        throw Exception('Shop settings not found');
      }
      return ShopSettingsModel.fromFirestore(
        docSnapshot.id,
        docSnapshot.data() as Map<String, dynamic>,
      );
    });
  }

  /// Create a new payment record
  /// Returns the payment document ID
  Future<String> createPayment({
    required String orderId,
    required String upiId,
    required double amount,
    required String customerPhone,
  }) async {
    try {
      final now = DateTime.now();
      final paymentRef = _firestore.collection('payments').doc();

      final payment = PaymentModel(
        id: paymentRef.id,
        orderId: orderId,
        upiId: upiId,
        amount: amount,
        customerPhone: customerPhone,
        status: PaymentStatus.pending,
        createdAt: now,
      );

      await paymentRef.set(payment.toFirestore());
      return paymentRef.id;
    } catch (e) {
      throw Exception('Failed to create payment: $e');
    }
  }

  /// Upload payment screenshot to Firebase Storage
  /// Returns the download URL
  Future<String> uploadPaymentScreenshot({
    required File imageFile,
    required String orderId,
    required String paymentId,
  }) async {
    try {
      // Path: payment-screenshots/{orderId}/{paymentId}.jpg
      final path = 'payment-screenshots/$orderId/$paymentId.jpg';
      final ref = _storage.ref(path);

      // Upload file
      await ref.putFile(imageFile);

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload screenshot: $e');
    }
  }

  /// Update payment with screenshot URL and mark as verification pending
  Future<void> updatePaymentScreenshot({
    required String paymentId,
    required String screenshotUrl,
  }) async {
    try {
      await _firestore.collection('payments').doc(paymentId).update({
        'screenshotUrl': screenshotUrl,
        'status': PaymentStatus.verificationPending.name,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update payment screenshot: $e');
    }
  }

  /// Get payment record by ID
  Future<PaymentModel?> getPayment(String paymentId) async {
    try {
      final docSnapshot =
          await _firestore.collection('payments').doc(paymentId).get();

      if (!docSnapshot.exists) {
        return null;
      }

      return PaymentModel.fromFirestore(
        docSnapshot.id,
        docSnapshot.data() as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Failed to fetch payment: $e');
    }
  }

  /// Get payment by order ID
  Future<PaymentModel?> getPaymentByOrderId(String orderId) async {
    try {
      final querySnapshot = await _firestore
          .collection('payments')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      return PaymentModel.fromFirestore(
        doc.id,
        doc.data(),
      );
    } catch (e) {
      throw Exception('Failed to fetch payment by order: $e');
    }
  }

  /// Watch payment status in real-time
  Stream<PaymentModel?> watchPayment(String paymentId) {
    return _firestore
        .collection('payments')
        .doc(paymentId)
        .snapshots()
        .map((docSnapshot) {
      if (!docSnapshot.exists) {
        return null;
      }
      return PaymentModel.fromFirestore(
        docSnapshot.id,
        docSnapshot.data() as Map<String, dynamic>,
      );
    });
  }

  /// Get all payments for a customer
  Future<List<PaymentModel>> getCustomerPayments(String customerPhone) async {
    try {
      final querySnapshot = await _firestore
          .collection('payments')
          .where('customerPhone', isEqualTo: customerPhone)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PaymentModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch customer payments: $e');
    }
  }

  /// Update order status to 'Payment Verification Pending'
  /// Called after payment screenshot is uploaded
  Future<void> updateOrderPaymentStatus(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'Payment Verification Pending',
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Admin action: Verify payment (approve)
  /// Updates payment status and order status
  Future<void> verifyPayment(String paymentId, String orderId) async {
    try {
      final now = DateTime.now();

      // Update payment
      await _firestore.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.verified.name,
        'verifiedAt': now,
        'updatedAt': now,
      });

      // Update order status to 'Confirmed'
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'Confirmed',
        'updatedAt': now,
      });
    } catch (e) {
      throw Exception('Failed to verify payment: $e');
    }
  }

  /// Admin action: Reject payment
  /// Updates payment status and optionally adds rejection reason
  Future<void> rejectPayment({
    required String paymentId,
    required String orderId,
    String? rejectionReason,
  }) async {
    try {
      final now = DateTime.now();

      // Update payment
      await _firestore.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.rejected.name,
        'rejectionReason': rejectionReason,
        'updatedAt': now,
      });

      // Update order status to 'Payment Rejected'
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'Payment Rejected',
        'updatedAt': now,
      });
    } catch (e) {
      throw Exception('Failed to reject payment: $e');
    }
  }

  /// Get all pending verifications (for admin dashboard)
  Future<List<PaymentModel>> getPendingVerifications() async {
    try {
      final querySnapshot = await _firestore
          .collection('payments')
          .where('status', isEqualTo: PaymentStatus.verificationPending.name)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PaymentModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch pending verifications: $e');
    }
  }

  /// Stream of pending verifications for real-time admin dashboard
  Stream<List<PaymentModel>> watchPendingVerifications() {
    return _firestore
        .collection('payments')
        .where('status', isEqualTo: PaymentStatus.verificationPending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs
          .map((doc) => PaymentModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Delete payment screenshot from storage
  /// (for admin cleanup or correction)
  Future<void> deletePaymentScreenshot(
      String orderId, String paymentId) async {
    try {
      final path = 'payment-screenshots/$orderId/$paymentId.jpg';
      await _storage.ref(path).delete();
    } catch (e) {
      // Silently fail if file doesn't exist
      print('Failed to delete screenshot: $e');
    }
  }

  /// Get total payments for a date range (analytics)
  Future<double> getTotalPaymentsForPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('payments')
          .where('status', isEqualTo: PaymentStatus.verified.name)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      double total = 0;
      for (final doc in querySnapshot.docs) {
        final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
        total += amount;
      }

      return total;
    } catch (e) {
      throw Exception('Failed to calculate total payments: $e');
    }
  }
}
