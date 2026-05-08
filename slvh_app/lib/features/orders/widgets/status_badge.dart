import 'package:flutter/material.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';

/// Widget to display order status as a colored badge
class StatusBadge extends StatelessWidget {
  final OrderStatus status;
  final bool isCompact;
  final VoidCallback? onTap;

  const StatusBadge({
    Key? key,
    required this.status,
    this.isCompact = false,
    this.onTap,
  }) : super(key: key);

  /// Get color for status
  Color _getStatusColor() {
    switch (status) {
      case OrderStatus.confirmed:
      case OrderStatus.readyForPickup:
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.pendingPayment:
      case OrderStatus.paymentVerificationPending:
        return Colors.orange;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  /// Get icon for status
  IconData _getStatusIcon() {
    switch (status) {
      case OrderStatus.pendingPayment:
        return Icons.payment;
      case OrderStatus.paymentVerificationPending:
        return Icons.hourglass_bottom;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.preparing:
        return Icons.local_dining;
      case OrderStatus.readyForPickup:
        return Icons.done_all;
      case OrderStatus.completed:
        return Icons.task_alt;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  /// Get progress indicator (0-1) for visual progress
  double _getProgress() {
    switch (status) {
      case OrderStatus.pendingPayment:
        return 0.1;
      case OrderStatus.paymentVerificationPending:
        return 0.2;
      case OrderStatus.confirmed:
        return 0.4;
      case OrderStatus.preparing:
        return 0.6;
      case OrderStatus.readyForPickup:
        return 0.8;
      case OrderStatus.completed:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final icon = _getStatusIcon();
    final label = status.label;

    if (isCompact) {
      // Compact badge for lists
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Full badge for detail screens
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Row(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Status',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  status == OrderStatus.cancelled
                      ? Icons.error_outline
                      : Icons.info_outline,
                  color: color,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress indicator
            _buildProgressIndicator(color),

            // Status description
            const SizedBox(height: 12),
            _buildStatusDescription(color),
          ],
        ),
      ),
    );
  }

  /// Build progress indicator
  Widget _buildProgressIndicator(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(_getProgress() * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _getProgress(),
            minHeight: 6,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  /// Build status description
  Widget _buildStatusDescription(Color color) {
    String description;

    switch (status) {
      case OrderStatus.pendingPayment:
        description = 'Waiting for payment. Please complete payment to proceed.';
        break;
      case OrderStatus.paymentVerificationPending:
        description = 'Payment screenshot submitted. Awaiting admin verification.';
        break;
      case OrderStatus.confirmed:
        description = 'Payment verified. Your order is confirmed and being prepared.';
        break;
      case OrderStatus.preparing:
        description = 'Your order is being prepared. We\'ll notify when ready.';
        break;
      case OrderStatus.readyForPickup:
        description = 'Your order is ready! Please pick it up at the scheduled time.';
        break;
      case OrderStatus.completed:
        description = 'Order completed. Thank you for your purchase!';
        break;
      case OrderStatus.cancelled:
        description = 'This order has been cancelled.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        description,
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Timeline widget showing order progression
class OrderStatusTimeline extends StatelessWidget {
  final OrderStatus currentStatus;
  final DateTime createdAt;
  final DateTime? completedAt;

  const OrderStatusTimeline({
    Key? key,
    required this.currentStatus,
    required this.createdAt,
    this.completedAt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statuses = [
      OrderStatus.pendingPayment,
      OrderStatus.paymentVerificationPending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.readyForPickup,
      OrderStatus.completed,
    ];

    final currentIndex = statuses.indexOf(currentStatus);

    return Column(
      children: [
        for (int i = 0; i < statuses.length; i++) ...[
          _TimelineStep(
            status: statuses[i],
            isCompleted: i < currentIndex || currentStatus == statuses[i],
            isActive: currentStatus == statuses[i],
            timestamp: _getTimestamp(statuses[i], currentIndex, i),
          ),
          if (i < statuses.length - 1)
            _TimelineConnector(
              isCompleted: i < currentIndex,
            ),
        ],
      ],
    );
  }

  /// Get timestamp for status
  String _getTimestamp(
    OrderStatus status,
    int currentIndex,
    int statusIndex,
  ) {
    if (statusIndex == 0) {
      return 'Created ${_formatTime(createdAt)}';
    }
    if (statusIndex == currentIndex && currentIndex > 0) {
      return 'In progress...';
    }
    if (statusIndex < currentIndex) {
      return 'Completed';
    }
    return 'Pending';
  }

  /// Format time
  String _formatTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}

/// Individual timeline step
class _TimelineStep extends StatelessWidget {
  final OrderStatus status;
  final bool isCompleted;
  final bool isActive;
  final String timestamp;

  const _TimelineStep({
    required this.status,
    required this.isCompleted,
    required this.isActive,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? Colors.green : Colors.grey[400]!;

    return Row(
      children: [
        // Dot
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? color.withOpacity(0.2) : Colors.transparent,
            border: Border.all(
              color: color,
              width: isActive ? 3 : 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(
                    Icons.check,
                    color: color,
                    size: 20,
                  )
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),

        // Status label and timestamp
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timestamp,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Timeline connector line
class _TimelineConnector extends StatelessWidget {
  final bool isCompleted;

  const _TimelineConnector({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 18),
      child: Container(
        width: 2,
        height: 24,
        color: isCompleted ? Colors.green : Colors.grey[300],
      ),
    );
  }
}
