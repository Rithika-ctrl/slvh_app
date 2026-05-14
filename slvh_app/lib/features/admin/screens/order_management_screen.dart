import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../orders/models/order_model.dart';
import '../widgets/order_row.dart';

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
  final TextEditingController _searchController = TextEditingController();

  // Data
  bool _isLoading = true;
  List<OrderModel> _allFetchedOrders = [];
  List<OrderModel> _filteredOrders = [];

  // Customer name cache: customerId (phone) -> display name
  final Map<String, String> _customerNameCache = {};

  // Per-row updating state
  final Set<String> _updatingOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Data Loading ─────────────────────────────────────────────

  void _loadOrders() {
    setState(() => _isLoading = true);
    _ordersSubscription?.cancel();

    Query query = _firestore.collection('orders');

    if (_selectedStatus != null) {
      query = query.where('status', isEqualTo: _selectedStatus!.name);
    }

    if (_selectedDateRange != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: _selectedDateRange!.start);
      final end = _selectedDateRange!.end.add(const Duration(days: 1));
      query = query.where('createdAt', isLessThan: end);
    }

    query = query.orderBy('createdAt', descending: true);

    _ordersSubscription = query.snapshots().listen(
      (snapshot) async {
        if (!mounted) return;

        final orders = snapshot.docs
            .map((doc) => OrderModel.fromFirestore(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        // Fetch customer names for any new customer IDs
        await _prefetchCustomerNames(orders);

        if (!mounted) return;
        setState(() {
          _allFetchedOrders = orders;
          _isLoading = false;
          _applyClientFilters();
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnack('Error loading orders: $e');
      },
    );
  }

  /// Fetches display names from `users/{phone}` for any IDs not yet cached.
  Future<void> _prefetchCustomerNames(List<OrderModel> orders) async {
    final uncached = orders
        .map((o) => o.customerId)
        .toSet()
        .where((id) => !_customerNameCache.containsKey(id))
        .toList();

    if (uncached.isEmpty) return;

    // Firestore 'in' queries are limited to 30 items; chunk if needed.
    const chunkSize = 30;
    for (int i = 0; i < uncached.length; i += chunkSize) {
      final chunk = uncached.sublist(
          i, i + chunkSize > uncached.length ? uncached.length : i + chunkSize);

      try {
        final snap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final name = (data['name'] as String?)?.trim() ??
              (data['displayName'] as String?)?.trim() ??
              '';
          _customerNameCache[doc.id] = name;
        }
      } catch (_) {
        // Silently ignore; IDs will just show the phone number.
      }

      // Ensure every ID in chunk has an entry (even if lookup failed).
      for (final id in chunk) {
        _customerNameCache.putIfAbsent(id, () => '');
      }
    }
  }

  void _applyClientFilters() {
    _filteredOrders = _allFetchedOrders.where((order) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (_customerNameCache[order.customerId] ?? '').toLowerCase();
      return order.id.toLowerCase().contains(q) ||
          order.customerId.toLowerCase().contains(q) ||
          name.contains(q);
    }).toList();
  }

  // ── Status Update ─────────────────────────────────────────────

  Future<void> _updateOrderStatus(OrderModel order, OrderStatus newStatus) async {
    setState(() => _updatingOrderIds.add(order.id));

    try {
      final data = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (newStatus == OrderStatus.completed) {
        data['completedAt'] = FieldValue.serverTimestamp();
      }
      await _firestore.collection('orders').doc(order.id).update(data);
      _showSnack('Status updated to "${newStatus.label}"');
    } catch (e) {
      _showSnack('Failed to update status: $e');
    } finally {
      if (mounted) setState(() => _updatingOrderIds.remove(order.id));
    }
  }

  // ── CSV Export ────────────────────────────────────────────────

  Future<void> _exportToCsv() async {
    if (_filteredOrders.isEmpty) {
      _showSnack('No orders to export');
      return;
    }

    try {
      final rows = <List<dynamic>>[
        [
          'Order ID',
          'Customer Phone',
          'Customer Name',
          'Date',
          'Status',
          'Items',
          'Subtotal',
          'Tax',
          'Total',
          'Payment Status',
          'Pickup Date',
          'Pickup Time',
        ],
      ];

      for (final order in _filteredOrders) {
        rows.add([
          order.id,
          order.customerId,
          _customerNameCache[order.customerId] ?? '',
          DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt),
          order.status.label,
          order.items.map((i) => '${i.quantity}x ${i.productName}').join('; '),
          order.subtotal.toStringAsFixed(2),
          order.tax.toStringAsFixed(2),
          order.total.toStringAsFixed(2),
          order.paymentStatus ?? 'N/A',
          order.pickupDate,
          order.pickupTime,
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final fileName =
          'orders_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: utf8.encode(csv),
        ext: 'csv',
        mimeType: MimeType.csv,
      );
    } catch (e) {
      _showSnack('Export failed: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatus = null;
      _selectedDateRange = null;
      _searchQuery = '';
    });
    _loadOrders();
  }

  bool get _hasActiveFilters =>
      _selectedStatus != null ||
      _selectedDateRange != null ||
      _searchQuery.isNotEmpty;

  // ── Build ─────────────────────────────────────────────────────

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
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export to CSV',
            onPressed: _exportToCsv,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allFetchedOrders.isEmpty
                    ? _buildEmptyState('No orders found.')
                    : _filteredOrders.isEmpty
                        ? _buildEmptyState('No orders match your filters.')
                        : _buildTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by ID, phone, or name\u2026',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyClientFilters();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  borderSide:
                      const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  borderSide:
                      const BorderSide(color: AppColors.cardBorder),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyClientFilters();
                });
              },
            ),
          ),

          // Status filter
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<OrderStatus?>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All Statuses')),
                ...OrderStatus.values.map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedStatus = val);
                _loadOrders();
              },
            ),
          ),

          // Date range
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range_outlined, size: 18),
            label: Text(
              _selectedDateRange == null
                  ? 'Date Range'
                  : '${DateFormat('MMM d').format(_selectedDateRange!.start)}'
                      ' \u2013 '
                      '${DateFormat('MMM d').format(_selectedDateRange!.end)}',
              style: TextStyle(
                color: _selectedDateRange != null
                    ? AppColors.orange
                    : AppColors.textDark,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _selectedDateRange != null
                    ? AppColors.orange
                    : AppColors.cardBorder,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              ),
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate:
                    DateTime.now().add(const Duration(days: 30)),
                initialDateRange: _selectedDateRange,
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: AppColors.orange,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _selectedDateRange = picked);
                _loadOrders();
              }
            },
          ),

          // Clear filters
          if (_hasActiveFilters)
            TextButton.icon(
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('Clear'),
              onPressed: _clearFilters,
            ),

          // Order count chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.bgCreamLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_filteredOrders.length} order${_filteredOrders.length != 1 ? 's' : ''}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMid),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTableHeader(),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: _filteredOrders.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final order = _filteredOrders[index];
                  return OrderRow(
                    order: order,
                    customerName:
                        _customerNameCache[order.customerId] ?? '',
                    isUpdating: _updatingOrderIds.contains(order.id),
                    onStatusChanged: (newStatus) =>
                        _updateOrderStatus(order, newStatus),
                    onViewDetails: () =>
                        context.push('/admin/orders/${order.id}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
      letterSpacing: 0.5,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCreamLight.withOpacity(0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child:
                  Text('ORDER ID', style: headerStyle)),
          const SizedBox(width: 12),
          SizedBox(
              width: 120,
              child: Text('DATE', style: headerStyle)),
          const SizedBox(width: 12),
          Expanded(
              flex: 2,
              child:
                  Text('CUSTOMER', style: headerStyle)),
          const SizedBox(width: 12),
          SizedBox(
              width: 60,
              child: Text('ITEMS', style: headerStyle)),
          const SizedBox(width: 12),
          SizedBox(
              width: 80,
              child: Text('TOTAL', style: headerStyle, textAlign: TextAlign.right)),
          const SizedBox(width: 12),
          SizedBox(
              width: 200,
              child: Text('STATUS', style: headerStyle)),
          const SizedBox(width: 12),
          SizedBox(
              width: 110,
              child: Text('PICKUP', style: headerStyle)),
          const SizedBox(width: 8),
          const SizedBox(width: 40), // icon button space
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return EmptyStateWidget(
      icon: Icons.inbox_outlined,
      title: message,
      subtitle: _hasActiveFilters
          ? 'Try clearing your filters to see more orders.'
          : 'New orders will appear here.',
      iconColor: AppColors.textHint,
      actionButton: _hasActiveFilters
          ? TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters'),
            )
          : null,
    );
  }
}