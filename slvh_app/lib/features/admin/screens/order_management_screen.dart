import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:file_saver/file_saver.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../orders/models/order_model.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  
  // Filters
  OrderStatus? _selectedStatus;
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  
  bool _isLoading = true;
  List<OrderModel> _allFetchedOrders = [];
  List<OrderModel> _filteredOrders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  void _loadOrders() {
    setState(() {
      _isLoading = true;
    });

    _ordersSubscription?.cancel();

    Query query = _firestore.collection('orders');

    // Server-side status filter
    if (_selectedStatus != null) {
      query = query.where('status', isEqualTo: _selectedStatus!.name);
    }

    // Server-side date range filter
    if (_selectedDateRange != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: _selectedDateRange!.start);
      // End date must include the entire day
      final end = _selectedDateRange!.end.add(const Duration(days: 1));
      query = query.where('createdAt', isLessThan: end);
    }

    query = query.orderBy('createdAt', descending: true);

    _ordersSubscription = query.snapshots().listen((snapshot) {
      if (!mounted) return;
      
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
          
      setState(() {
        _allFetchedOrders = orders;
        _isLoading = false;
        _applyClientFilters();
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading orders: $e')),
      );
    });
  }

  void _applyClientFilters() {
    _filteredOrders = _allFetchedOrders.where((order) {
      // Search query filter (customer phone or order ID)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!order.id.toLowerCase().contains(q) &&
            !order.customerId.toLowerCase().contains(q)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  Future<void> _updateOrderStatus(OrderModel order, OrderStatus newStatus) async {
    try {
      final dataToUpdate = {
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (newStatus == OrderStatus.completed) {
        dataToUpdate['completedAt'] = FieldValue.serverTimestamp();
      }
      
      await _firestore.collection('orders').doc(order.id).update(dataToUpdate);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order status updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _exportToCsv() async {
    if (_filteredOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders to export')),
      );
      return;
    }

    try {
      List<List<dynamic>> csvData = [
        [
          'Order ID',
          'Customer Phone',
          'Date',
          'Status',
          'Items Summary',
          'Subtotal',
          'Tax',
          'Total',
          'Payment Status',
          'Pickup Slot'
        ],
      ];

      for (var order in _filteredOrders) {
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt);
        final itemsStr = order.items
            .map((item) => '${item.quantity}x ${item.productName}')
            .join('; ');
            
        csvData.add([
          order.id,
          order.customerId,
          dateStr,
          order.status.label,
          itemsStr,
          order.subtotal.toStringAsFixed(2),
          order.tax.toStringAsFixed(2),
          order.total.toStringAsFixed(2),
          order.paymentStatus ?? 'N/A',
          '${order.pickupDate} ${order.pickupTime}',
        ]);
      }

      String csvContent = const ListToCsvConverter().convert(csvData);
      
      final fileName = 'orders_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      
      final bytes = utf8.encode(csvContent);
      
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting CSV: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('Order Management'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to CSV',
            onPressed: _exportToCsv,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _buildFilters(),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _buildDataTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Box
          SizedBox(
            width: 250,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search ID or Phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyClientFilters();
                });
              },
            ),
          ),
          
          // Status Dropdown
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<OrderStatus?>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Statuses'),
                ),
                ...OrderStatus.values.map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedStatus = val;
                });
                _loadOrders();
              },
            ),
          ),

          // Date Range Picker
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(
              _selectedDateRange == null
                  ? 'Filter by Date'
                  : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 30)),
                initialDateRange: _selectedDateRange,
              );
              if (picked != null) {
                setState(() {
                  _selectedDateRange = picked;
                });
                _loadOrders();
              }
            },
          ),
          
          // Clear Filters
          if (_selectedStatus != null || _selectedDateRange != null || _searchQuery.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = null;
                  _selectedDateRange = null;
                  _searchQuery = '';
                });
                _loadOrders();
              },
              child: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allFetchedOrders.isEmpty) {
      return const Center(
        child: Text('No orders found.'),
      );
    }

    if (_filteredOrders.isEmpty) {
      return const Center(
        child: Text('No orders match your filters.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 16,
        minWidth: 1000,
        headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
        columns: const [
          DataColumn2(label: Text('Date'), size: ColumnSize.S),
          DataColumn2(label: Text('Order ID'), size: ColumnSize.M),
          DataColumn2(label: Text('Customer'), size: ColumnSize.M),
          DataColumn2(label: Text('Total'), size: ColumnSize.S, numeric: true),
          DataColumn2(label: Text('Status'), size: ColumnSize.M),
          DataColumn2(label: Text('Actions'), size: ColumnSize.S),
        ],
        rows: _filteredOrders.map((order) {
          final dateStr = DateFormat('MMM d, yyyy HH:mm').format(order.createdAt);
          final colorHex = order.status.getColorHex();
          final statusColor = Color(int.parse('FF$colorHex', radix: 16));

          return DataRow(
            cells: [
              DataCell(Text(dateStr)),
              DataCell(
                Text(
                  order.id, 
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              ),
              DataCell(Text(order.customerId)),
              DataCell(Text('₹${order.total.toStringAsFixed(2)}')),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<OrderStatus>(
                      value: order.status,
                      isDense: true,
                      iconSize: 16,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onChanged: (newStatus) {
                        if (newStatus != null && newStatus != order.status) {
                          _updateOrderStatus(order, newStatus);
                        }
                      },
                      items: OrderStatus.values.map((status) {
                        return DropdownMenuItem<OrderStatus>(
                          value: status,
                          child: Text(status.label),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.visibility, color: AppColors.orange),
                  tooltip: 'View Details',
                  onPressed: () {
                    context.push('/admin/orders/${order.id}');
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
