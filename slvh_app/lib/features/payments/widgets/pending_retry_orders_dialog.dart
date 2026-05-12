import 'package:flutter/material.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';
import 'package:slvh_app/core/constants/app_colors.dart';

/// Dialog shown on app startup if user has pending retry orders
/// Prompts user to complete payment verification
class PendingRetryOrdersDialog extends StatelessWidget {
  final List<OrderModel> pendingOrders;
  final VoidCallback onRetry;
  final VoidCallback? onDismiss;

  const PendingRetryOrdersDialog({
    Key? key,
    required this.pendingOrders,
    required this.onRetry,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final oldestOrder = pendingOrders.last; // Oldest (first to retry)
    final count = pendingOrders.length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline,
              color: Colors.orange[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: const Text(
              'Pending Payment Upload',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              children: [
                const TextSpan(text: 'You have '),
                TextSpan(
                  text: count == 1
                      ? 'an order'
                      : '$count orders',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const TextSpan(
                  text: ' waiting for payment verification. '
                      'Your payment was successful, but the proof upload needs to be completed.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Order details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order ID:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      oldestOrder.id.substring(0, 8),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      '₹${oldestOrder.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pickup:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      '${oldestOrder.pickupDate} at ${oldestOrder.pickupTime}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (count > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${count - 1} more ${count - 1 == 1 ? 'order' : 'orders'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Info box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.blue[700],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Complete the upload to get your order confirmed.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            if (onDismiss != null) onDismiss!();
          },
          child: const Text('Later'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onRetry();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Helper function to show pending retry orders dialog
Future<void> showPendingRetryOrdersDialog(
  BuildContext context, {
  required List<OrderModel> pendingOrders,
  required VoidCallback onRetry,
  VoidCallback? onDismiss,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PendingRetryOrdersDialog(
      pendingOrders: pendingOrders,
      onRetry: onRetry,
      onDismiss: onDismiss,
    ),
  );
}
