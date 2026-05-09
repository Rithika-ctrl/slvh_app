import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/services/auth_service.dart';
import '../../notifications/services/notification_service.dart';
import '../../payments/models/payment_model.dart';
import '../widgets/payment_review_card.dart';

class PaymentVerificationScreen extends StatefulWidget {
  const PaymentVerificationScreen({super.key});

  @override
  State<PaymentVerificationScreen> createState() =>
      _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final Set<String> _busyPaymentIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('Payment Verification'),
        centerTitle: false,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: _watchPendingPayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load pending payments: ${snapshot.error}'),
            );
          }

          final payments = snapshot.data ?? const [];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderSummary(count: payments.length),
                    const SizedBox(height: 16),
                    Expanded(
                      child: payments.isEmpty
                          ? const _EmptyPayments()
                          : ListView.separated(
                              itemCount: payments.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final payment = payments[index];
                                return PaymentReviewCard(
                                  payment: payment,
                                  isBusy: _busyPaymentIds.contains(payment.id),
                                  onViewScreenshot: () =>
                                      _openScreenshot(payment),
                                  onApprove: () => _approvePayment(payment),
                                  onReject: () => _rejectPayment(payment),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Stream<List<PaymentModel>> _watchPendingPayments() {
    return _firestore
        .collection('payments')
        .where('status', isEqualTo: PaymentStatus.verificationPending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> _approvePayment(PaymentModel payment) async {
    await _withBusyState(payment.id, () async {
      final admin = await _adminLabel();
      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();

      batch.update(_firestore.collection('payments').doc(payment.id), {
        'status': PaymentStatus.verified.name,
        'verified_by': admin,
        'verifiedAt': now,
        'updatedAt': now,
      });

      batch.update(_firestore.collection('orders').doc(payment.orderId), {
        'status': 'Confirmed',
        'paymentStatus': 'Verified',
        'updatedAt': now,
      });

      await batch.commit();
      await _notificationService.saveNotification(
        userId: payment.customerPhone,
        title: 'Payment Approved',
        body: 'Your payment has been verified. Your order is confirmed.',
        orderId: payment.orderId,
        orderStatus: 'Confirmed',
        actionUrl: '/order/${payment.orderId}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Payment approved for order ${payment.orderId}')),
      );
    });
  }

  Future<void> _rejectPayment(PaymentModel payment) async {
    final reason = await _askRejectReason();
    if (reason == null) return;

    await _withBusyState(payment.id, () async {
      final admin = await _adminLabel();
      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();

      batch.update(_firestore.collection('payments').doc(payment.id), {
        'status': PaymentStatus.rejected.name,
        'rejectionReason': reason,
        'verified_by': admin,
        'rejectedAt': now,
        'updatedAt': now,
      });

      batch.update(_firestore.collection('orders').doc(payment.orderId), {
        'status': 'Payment Rejected',
        'paymentStatus': 'Rejected',
        'updatedAt': now,
      });

      await batch.commit();
      await _notificationService.saveNotification(
        userId: payment.customerPhone,
        title: 'Payment Rejected',
        body: reason.isEmpty
            ? 'Your payment proof could not be verified. Please upload a clear screenshot again.'
            : 'Your payment proof was rejected: $reason',
        orderId: payment.orderId,
        orderStatus: 'Payment Rejected',
        actionUrl: '/order/${payment.orderId}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Payment rejected for order ${payment.orderId}')),
      );
    });
  }

  Future<void> _withBusyState(
    String paymentId,
    Future<void> Function() action,
  ) async {
    setState(() => _busyPaymentIds.add(paymentId));
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment update failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPaymentIds.remove(paymentId));
      }
    }
  }

  Future<String> _adminLabel() async {
    return await _authService.getCurrentAdminEmail() ?? 'admin';
  }

  Future<String?> _askRejectReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText:
                'Screenshot unclear, amount mismatch, wrong UPI reference...',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _openScreenshot(PaymentModel payment) {
    final screenshotUrl = payment.screenshotUrl;
    if (screenshotUrl == null || screenshotUrl.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ScreenshotReviewScreen(
          imageUrl: screenshotUrl,
          title: 'Order #${payment.orderId}',
        ),
      ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  final int count;

  const _HeaderSummary({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count pending payment${count == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'New uploaded screenshots appear here instantly.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 48,
            ),
            SizedBox(height: 12),
            Text('No payments waiting for review'),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotReviewScreen extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _ScreenshotReviewScreen({
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(imageUrl),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child:
              Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
        ),
      ),
    );
  }
}
