import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../orders/models/order_model.dart';

class OrderRow extends StatelessWidget {
  final OrderModel order;
  final String customerName;
  final bool isUpdating;
  final ValueChanged<OrderStatus> onStatusChanged;
  final VoidCallback onViewDetails;

  const OrderRow({
    super.key,
    required this.order,
    required this.customerName,
    required this.isUpdating,
    required this.onStatusChanged,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return Row(
      children: [
        Text(
          _shortId(order.id),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _formatDate(order.createdAt),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            customerName,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('${order.itemCount} items'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Rs ${order.total.toStringAsFixed(2)}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<OrderStatus>(
                value: order.status,
                isExpanded: true,
                onChanged: isUpdating
                    ? null
                    : (value) {
                        if (value != null && value != order.status) {
                          onStatusChanged(value);
                        }
                      },
                items: OrderStatus.values
                    .map(
                      (status) => DropdownMenuItem<OrderStatus>(
                        value: status,
                        child: Text(
                          status.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${order.pickupDate} ${order.pickupTime}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onViewDetails,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Details'),
        ),
      ],
    );
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  static String _formatDate(DateTime dateTime) {
    final date = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$date/$month/$year $hour:$minute';
  }

  static Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.confirmed:
      case OrderStatus.readyForPickup:
        return AppColors.success;
      case OrderStatus.preparing:
        return AppColors.catBlue;
      case OrderStatus.pendingPayment:
      case OrderStatus.paymentVerificationPending:
        return AppColors.orange;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }
}