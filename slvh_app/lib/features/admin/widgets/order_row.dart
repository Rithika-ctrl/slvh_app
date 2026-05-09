import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

    return InkWell(
      onTap: onViewDetails,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Order ID
            SizedBox(
              width: 100,
              child: Text(
                _shortId(order.id),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),

            // Date
            SizedBox(
              width: 120,
              child: Text(
                _formatDate(order.createdAt),
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),

            // Customer
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (customerName.isNotEmpty && customerName != order.customerId)
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    order.customerId,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Items count
            SizedBox(
              width: 60,
              child: Text(
                '${order.totalQuantity} item${order.totalQuantity != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
              ),
            ),
            const SizedBox(width: 12),

            // Total
            SizedBox(
              width: 80,
              child: Text(
                'Rs ${order.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),

            // Status dropdown
            SizedBox(
              width: 200,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: isUpdating
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            order.status.label,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<OrderStatus>(
                          value: order.status,
                          isExpanded: true,
                          isDense: true,
                          iconSize: 16,
                          icon: Icon(Icons.arrow_drop_down, color: statusColor),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onChanged: (value) {
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
                                      fontSize: 12,
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

            // Pickup slot
            SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order.pickupDate,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    order.pickupTime,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // View details button
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 20),
              color: AppColors.orange,
              tooltip: 'View Order Details',
              onPressed: onViewDetails,
            ),
          ],
        ),
      ),
    );
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 6)}\u2026';
  }

  static String _formatDate(DateTime dt) {
    return DateFormat('dd MMM, HH:mm').format(dt);
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