import 'package:flutter/material.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';
import 'package:slvh_app/features/payments/services/payment_retry_service.dart';
import 'package:slvh_app/core/constants/app_colors.dart';

/// Bottom sheet shown when payment upload fails
/// Provides user with options to retry, continue later, or contact support
class PaymentRetryBottomSheet extends StatefulWidget {
  final OrderModel order;
  final String paymentReference;
  final VoidCallback onRetry;
  final VoidCallback? onContactSupport;

  const PaymentRetryBottomSheet({
    Key? key,
    required this.order,
    required this.paymentReference,
    required this.onRetry,
    this.onContactSupport,
  }) : super(key: key);

  @override
  State<PaymentRetryBottomSheet> createState() =>
      _PaymentRetryBottomSheetState();
}

class _PaymentRetryBottomSheetState extends State<PaymentRetryBottomSheet> {
  final PaymentRetryService _retryService = PaymentRetryService();
  bool _isRetrying = false;
  String? _errorMessage;

  /// Handle retry button tap
  Future<void> _handleRetry() async {
    // Check if can retry again (rate limiting)
    if (!_retryService.canRetryAgain(widget.order)) {
      setState(() {
        _errorMessage = 'Please wait before retrying again';
      });
      return;
    }

    setState(() {
      _isRetrying = true;
      _errorMessage = null;
    });

    try {
      // Mark retry attempt in Firestore
      await _retryService.markRetryAttempt(widget.order.id);

      // Call the retry callback (parent handles actual retry logic)
      if (mounted) {
        widget.onRetry();
        // Close bottom sheet on success
        Navigator.pop(context, {'retried': true});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Retry failed: $e';
          _isRetrying = false;
        });
      }
    }
  }

  /// Handle continue later button tap
  void _handleContinueLater() {
    Navigator.pop(context, {'continueLater': true});
  }

  /// Handle contact support button tap
  void _handleContactSupport() {
    if (widget.onContactSupport != null) {
      widget.onContactSupport!();
    }
    Navigator.pop(context, {'contactSupport': true});
  }

  @override
  Widget build(BuildContext context) {
    final retryMessage = _retryService.getRetryMessage(widget.order);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Upload Failed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Retry attempt: ${widget.order.retryCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  retryMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                    children: const [
                      TextSpan(text: '💡 Tip: '),
                      TextSpan(
                        text: 'Your payment was successful. '
                            'We just need to confirm the receipt.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Order Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order ID:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    Text(
                      widget.order.id.substring(0, 8),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    Text(
                      '₹${widget.order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    Text(
                      '${widget.order.itemCount} items',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Error message if any
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action Buttons
          // Retry button (primary)
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isRetrying ? null : _handleRetry,
              icon: _isRetrying
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.8),
                        ),
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(
                _isRetrying ? 'Retrying...' : 'Retry Upload',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Continue Later button (secondary)
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isRetrying ? null : _handleContinueLater,
              icon: const Icon(Icons.schedule_rounded),
              label: const Text(
                'Continue Later',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Contact Support button (tertiary)
          SizedBox(
            height: 48,
            child: TextButton.icon(
              onPressed: _isRetrying ? null : _handleContactSupport,
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text(
                'Contact Support',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
