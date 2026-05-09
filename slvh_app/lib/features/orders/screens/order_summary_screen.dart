import 'package:flutter/material.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';
import 'package:slvh_app/features/orders/widgets/status_badge.dart';

/// Order confirmation/summary screen
/// Shown after order is created successfully
class OrderSummaryScreen extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onContinueShopping;
  final VoidCallback onViewOrders;

  const OrderSummaryScreen({
    Key? key,
    required this.order,
    required this.onContinueShopping,
    required this.onViewOrders,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success message
            _buildSuccessCard(),
            const SizedBox(height: 24),

            // Order ID
            _buildOrderIdCard(),
            const SizedBox(height: 20),

            // Order status
            _buildStatusCard(),
            const SizedBox(height: 20),

            // Pickup details
            _buildPickupDetailsCard(context),
            const SizedBox(height: 20),

            // Items summary
            _buildItemsSummaryCard(context),
            const SizedBox(height: 20),

            // Price breakdown
            _buildPriceSummaryCard(),
            const SizedBox(height: 24),

            // Next steps
            _buildNextStepsCard(),
            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Build success message card
  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[700],
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            '✅ Order Created Successfully!',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your order has been placed and is awaiting payment verification.',
            style: TextStyle(
              color: Colors.green[600],
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build order ID card
  Widget _buildOrderIdCard() {
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
          Text(
            'Order ID',
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.id,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(
                Icons.copy_outlined,
                color: Colors.blue[700],
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build status card
  Widget _buildStatusCard() {
    return StatusBadge(
      status: order.status,
      isCompact: false,
    );
  }

  /// Build pickup details card
  Widget _buildPickupDetailsCard(BuildContext context) {
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
            'Pickup Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _PickupDetailRow(
            icon: Icons.calendar_today,
            label: 'Date',
            value: order.pickupDate,
          ),
          const SizedBox(height: 8),
          _PickupDetailRow(
            icon: Icons.access_time,
            label: 'Time',
            value: order.pickupTime,
          ),
          const SizedBox(height: 8),
          _PickupDetailRow(
            icon: Icons.location_on,
            label: 'Location',
            value: 'Smart Shop Store',
          ),
        ],
      ),
    );
  }

  /// Build items summary card
  Widget _buildItemsSummaryCard(BuildContext context) {
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
            'Order Items (${order.itemCount})',
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
              return _OrderItemRow(item: item);
            },
          ),
        ],
      ),
    );
  }

  /// Build price summary card
  Widget _buildPriceSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Column(
        children: [
          _PriceSummaryRow(
            label: 'Subtotal',
            value: '₹${order.subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _PriceSummaryRow(
            label: 'Tax (5%)',
            value: '₹${order.tax.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.orange[300]),
          const SizedBox(height: 12),
          _PriceSummaryRow(
            label: 'Total Amount',
            value: '₹${order.total.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  /// Build next steps card
  Widget _buildNextStepsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.indigo[700]),
              const SizedBox(width: 8),
              Text(
                'What Happens Next',
                style: TextStyle(
                  color: Colors.indigo[700],
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NextStepItem(
            number: '1',
            text: 'Payment verification (admin review)',
            color: Colors.indigo[700]!,
          ),
          const SizedBox(height: 8),
          _NextStepItem(
            number: '2',
            text: 'Order preparation starts',
            color: Colors.indigo[700]!,
          ),
          const SizedBox(height: 8),
          _NextStepItem(
            number: '3',
            text: 'You\'ll receive notification when ready',
            color: Colors.indigo[700]!,
          ),
          const SizedBox(height: 8),
          _NextStepItem(
            number: '4',
            text: 'Pick up at scheduled time',
            color: Colors.indigo[700]!,
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: onViewOrders,
            icon: const Icon(Icons.receipt_long),
            label: const Text('View My Orders'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onContinueShopping,
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Continue Shopping'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

}

/// Pickup detail row
class _PickupDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PickupDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange[700], size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Order item row
class _OrderItemRow extends StatelessWidget {
  final OrderItem item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Qty: ${item.quantity}${item.selectedTierUnit != null ? ' (${item.selectedTierUnit})' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                if (item.discountPercent != null && item.discountPercent! > 0)
                  Text(
                    '${item.discountPercent!.toStringAsFixed(0)}% discount',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${item.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Price summary row
class _PriceSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _PriceSummaryRow({
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
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.black87 : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? Colors.orange[700] : Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Next step item
class _NextStepItem extends StatelessWidget {
  final String number;
  final String text;
  final Color color;

  const _NextStepItem({
    required this.number,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
