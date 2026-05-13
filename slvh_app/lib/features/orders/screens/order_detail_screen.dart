import 'package:flutter/material.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';
import 'package:slvh_app/features/orders/services/order_service.dart';
import 'package:slvh_app/features/orders/services/order_cancellation_service.dart';
import 'package:slvh_app/features/orders/widgets/status_badge.dart';
import 'package:slvh_app/features/orders/widgets/cancel_order_dialog.dart';
import 'package:slvh_app/features/payments/services/payment_rejection_service.dart';
import 'package:slvh_app/features/payments/screens/refund_instructions_screen.dart';
import 'package:slvh_app/features/settings/services/settings_service.dart';

/// Order detail screen showing full order information and real-time status
class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  final OrderCancellationService _cancellationService = OrderCancellationService();
  final PaymentRejectionService _paymentRejectionService =
      PaymentRejectionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<OrderModel?>(
        stream: _orderService.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final order = snapshot.data;
          if (order == null) {
            return const Center(
              child: Text('Order not found'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order header
                _buildOrderHeader(order),
                const SizedBox(height: 20),

                // Status timeline
                _buildStatusTimeline(order),
                const SizedBox(height: 20),

                // Order details
                _buildOrderDetailsCard(order),
                const SizedBox(height: 20),

                // Items
                _buildItemsCard(order),
                const SizedBox(height: 20),

                // Price breakdown
                _buildPriceBreakdownCard(order),
                const SizedBox(height: 20),

                // Pickup information
                _buildPickupInformationCard(order),
                const SizedBox(height: 24),

                // Cancel order button (visible only when payment verification pending
                // AND the cancel window is still open)
                if (order.status == OrderStatus.paymentVerificationPending)
                  FutureBuilder(
                    future: SettingsService.instance.getSettings(),
                    builder: (context, snapshot) {
                      final cancelWindowMinutes =
                          snapshot.data?.cancelWindowMinutes ?? 30;
                      final canCancel = _cancellationService.canCancelOrder(
                        order,
                        cancelWindowMinutes: cancelWindowMinutes,
                      );
                      final minutesLeft = _cancellationService
                          .minutesLeftToCancel(order,
                              cancelWindowMinutes: cancelWindowMinutes);
                      if (!canCancel) return const SizedBox.shrink();
                      return _buildCancelOrderButton(
                          context, order, minutesLeft, cancelWindowMinutes);
                    },
                  ),
                
                // Payment rejection notice (visible when payment rejected)
                if (order.status == OrderStatus.paymentRejected)
                  _buildPaymentRejectionNotice(context, order),
                
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build order header
  Widget _buildOrderHeader(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.id,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Icon(Icons.receipt_long, color: Colors.blue[700], size: 32),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                _formatFullDate(order.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build status timeline
  Widget _buildStatusTimeline(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          OrderStatusTimeline(
            currentStatus: order.status,
            createdAt: order.createdAt,
            completedAt: order.completedAt,
          ),
        ],
      ),
    );
  }

  /// Build order details card
  Widget _buildOrderDetailsCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Status', value: order.status.label),
          const SizedBox(height: 8),
          _DetailRow(label: 'Items', value: '${order.itemCount}'),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Total Quantity',
            value: '${order.totalQuantity} units',
          ),
          if (order.paymentStatus != null) ...[
            const SizedBox(height: 8),
            _DetailRow(label: 'Payment Status', value: order.paymentStatus!),
          ],
          if (order.completedAt != null) ...[
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Completed On',
              value: _formatFullDate(order.completedAt!),
            ),
          ],
        ],
      ),
    );
  }

  /// Build items card
  Widget _buildItemsCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: order.items.length,
            separatorBuilder: (_, __) => Divider(color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final item = order.items[index];
              return _ItemRow(item: item);
            },
          ),
        ],
      ),
    );
  }

  /// Build price breakdown card
  Widget _buildPriceBreakdownCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Column(
        children: [
          _PriceRow(
            label: 'Subtotal',
            value: '₹${order.subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _PriceRow(
            label: 'Tax (5%)',
            value: '₹${order.tax.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.orange[300]),
          const SizedBox(height: 12),
          _PriceRow(
            label: 'Total',
            value: '₹${order.total.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  /// Build pickup information card
  Widget _buildPickupInformationCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.green[700], size: 24),
              const SizedBox(width: 12),
              Text(
                'Pickup Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.calendar_today,
            label: 'Date',
            value: order.pickupDate,
            color: Colors.green[700]!,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.access_time,
            label: 'Time',
            value: order.pickupTime,
            color: Colors.green[700]!,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: 'Smart Shop Store',
            color: Colors.green[700]!,
          ),
        ],
      ),
    );
  }

  /// Build cancel order button
  Widget _buildCancelOrderButton(
    BuildContext context,
    OrderModel order,
    int minutesLeft,
    int cancelWindowMinutes,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Order Cancellation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  minutesLeft > 1
                      ? 'You can cancel this order within the next $minutesLeft minutes '
                          '(within $cancelWindowMinutes min of placing it).'
                      : 'Last chance — cancel this order now before the window closes.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showCancelOrderDialog(context, order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel Order',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show cancel order confirmation dialog
  Future<void> _showCancelOrderDialog(BuildContext context, OrderModel order) async {
    // Load current settings to enforce the live cancel_window_minutes
    final settings = await SettingsService.instance.getSettings();
    final cancelWindowMinutes = settings.cancelWindowMinutes;

    // Guard: check eligibility before opening the dialog
    if (!_cancellationService.canCancelOrder(
      order,
      cancelWindowMinutes: cancelWindowMinutes,
    )) {
      if (!mounted) return;
      final isStatusOk =
          order.status == OrderStatus.paymentVerificationPending;
      final msg = isStatusOk
          ? 'The $cancelWindowMinutes-minute cancellation window has closed. '
              'Please contact support if you need to cancel.'
          : 'This order can no longer be cancelled.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.orange[700],
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final result = await showCancelOrderDialog(
      context,
      order: order,
      onCancel: () {
        // Trigger cancellation via OrderCancellationService (fire-and-forget).
        _cancellationService.cancelOrder(
          orderId: order.id,
          order: order,
          reason: '',               // Reason is passed back via dialog result; service re-records it
          cancelWindowMinutes: cancelWindowMinutes,
        );
      },
      cancellationReasons: OrderCancellationService.cancellationReasons,
    );

    if (result != null && result['cancelled'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Order cancelled successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Build payment rejection notice
  Widget _buildPaymentRejectionNotice(BuildContext context, OrderModel order) {
    return StreamBuilder(
      stream: _paymentRejectionService.watchRejectedPaymentByOrderId(order.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container();
        }

        final payment = snapshot.data;
        if (payment == null) {
          return Container();
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Rejected',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (payment.rejectionReason != null)
                                Text(
                                  payment.rejectionReason!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showRefundInstructions(context, order, payment),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View Refund Instructions',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Navigate to refund instructions screen
  Future<void> _showRefundInstructions(
    BuildContext context,
    OrderModel order,
    dynamic payment,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RefundInstructionsScreen(
          order: order,
          payment: payment,
          onRetryPayment: () {
            // Navigate to payment screen for retry
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Retry payment flow (TODO: implement)'),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Detail row helper
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Item row helper
class _ItemRow extends StatelessWidget {
  final OrderItem item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '₹${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Qty: ${item.quantity}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              if (item.selectedTierUnit != null) ...[
                const Text(' • ', style: TextStyle(color: Colors.grey)),
                Text(
                  item.selectedTierUnit!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
              if (item.discountPercent != null && item.discountPercent! > 0) ...[
                const Text(' • ', style: TextStyle(color: Colors.grey)),
                Text(
                  '${item.discountPercent!.toStringAsFixed(0)}% off',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Price row helper
class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.black87 : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? Colors.orange[700] : Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Info row helper
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Format date helper
String _formatFullDate(DateTime dateTime) {
  final months = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return '${dateTime.day} ${months[dateTime.month]} ${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}