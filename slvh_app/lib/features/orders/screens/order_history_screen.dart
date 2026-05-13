import 'package:flutter/material.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';
import 'package:slvh_app/features/orders/services/order_service.dart';
import 'package:slvh_app/features/orders/widgets/status_badge.dart';
import 'package:slvh_app/shared/widgets/empty_state_widget.dart';

/// Order history screen showing all customer orders
class OrderHistoryScreen extends StatefulWidget {
  final String customerId;
  final Function(String orderId)? onOrderTap;

  const OrderHistoryScreen({
    Key? key,
    required this.customerId,
    this.onOrderTap,
  }) : super(key: key);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final OrderService _orderService = OrderService();
  String _selectedFilter = 'all'; // all, active, completed, cancelled

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter tabs
          _buildFilterTabs(),

          // Orders list
          Expanded(
            child: _buildOrdersList(),
          ),
        ],
      ),
    );
  }

  /// Build filter tabs
  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            isSelected: _selectedFilter == 'all',
            onTap: () => setState(() => _selectedFilter = 'all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Active',
            isSelected: _selectedFilter == 'active',
            onTap: () => setState(() => _selectedFilter = 'active'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Completed',
            isSelected: _selectedFilter == 'completed',
            onTap: () => setState(() => _selectedFilter = 'completed'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Cancelled',
            isSelected: _selectedFilter == 'cancelled',
            onTap: () => setState(() => _selectedFilter = 'cancelled'),
          ),
        ],
      ),
    );
  }

  /// Build orders list
  Widget _buildOrdersList() {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.watchCustomerOrders(widget.customerId),
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

        final orders = snapshot.data ?? [];

        // Filter orders
        final filteredOrders = _filterOrders(orders);

        if (filteredOrders.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final order = filteredOrders[index];
            return _OrderCard(
              order: order,
              onTap: () => widget.onOrderTap?.call(order.id),
            );
          },
        );
      },
    );
  }

  /// Filter orders based on selected filter
  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    switch (_selectedFilter) {
      case 'active':
        return orders.where((o) => o.isActive).toList();
      case 'completed':
        return orders
            .where((o) => o.status == OrderStatus.completed)
            .toList();
      case 'cancelled':
        return orders
            .where((o) => o.status == OrderStatus.cancelled)
            .toList();
      default:
        return orders;
    }
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.shopping_bag_outlined,
      title: 'No orders yet',
      subtitle: 'Start shopping to create your first order',
      actionButton: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.shopping_bag),
        label: const Text('Start Shopping'),
      ),
      ),
    );
  }
}

/// Order card widget
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const _OrderCard({
    required this.order,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            // Order header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(order.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: order.status, isCompact: true),
              ],
            ),
            const SizedBox(height: 12),

            // Items count and total
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${order.itemCount} item${order.itemCount > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const Spacer(),
                Text(
                  '₹${order.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Pickup info
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Pickup: ${order.pickupDate} at ${order.pickupTime}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick action button
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('View Details', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format date
  String _formatDate(DateTime dateTime) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dateTime.day} ${months[dateTime.month]} ${dateTime.year}';
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[700] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.orange[700]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
