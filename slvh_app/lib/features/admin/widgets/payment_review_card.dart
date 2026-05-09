import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../payments/models/payment_model.dart';

class PaymentReviewCard extends StatelessWidget {
  final PaymentModel payment;
  final bool isBusy;
  final VoidCallback onViewScreenshot;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const PaymentReviewCard({
    super.key,
    required this.payment,
    required this.isBusy,
    required this.onViewScreenshot,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 680;
          final preview = _ScreenshotPreview(
            screenshotUrl: payment.screenshotUrl,
            onTap: onViewScreenshot,
          );
          final details = _PaymentDetails(payment: payment);
          final actions = _PaymentActions(
            isBusy: isBusy,
            onApprove: onApprove,
            onReject: onReject,
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                preview,
                const SizedBox(width: 16),
                Expanded(child: details),
                const SizedBox(width: 16),
                SizedBox(width: 180, child: actions),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              preview,
              const SizedBox(height: 14),
              details,
              const SizedBox(height: 14),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ScreenshotPreview extends StatelessWidget {
  final String? screenshotUrl;
  final VoidCallback onTap;

  const _ScreenshotPreview({
    required this.screenshotUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: screenshotUrl == null || screenshotUrl!.isEmpty ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 160,
        height: 160,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.orangePale,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: screenshotUrl == null || screenshotUrl!.isEmpty
            ? const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.textHint,
                  size: 38,
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: screenshotUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.62),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.zoom_out_map,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PaymentDetails extends StatelessWidget {
  final PaymentModel payment;

  const _PaymentDetails({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order #${_shortId(payment.orderId)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        _InfoLine(
          icon: Icons.currency_rupee,
          label: 'Amount',
          value: 'Rs ${payment.amount.toStringAsFixed(2)}',
        ),
        _InfoLine(
          icon: Icons.phone_outlined,
          label: 'Customer',
          value: payment.customerPhone,
        ),
        _InfoLine(
          icon: Icons.account_balance_wallet_outlined,
          label: 'UPI',
          value: payment.upiId.isEmpty ? 'Not recorded' : payment.upiId,
        ),
        _InfoLine(
          icon: Icons.schedule,
          label: 'Uploaded',
          value: _formatDateTime(payment.updatedAt ?? payment.createdAt),
        ),
      ],
    );
  }

  static String _shortId(String value) {
    return value.length <= 10 ? value : value.substring(0, 10);
  }

  static String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, color: AppColors.orange, size: 18),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentActions extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PaymentActions({
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: isBusy ? null : onApprove,
          icon: isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text('Approve'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: isBusy ? null : onReject,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Reject'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
