import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../orders/models/order_model.dart';
import '../widgets/best_sellers_list.dart';
import '../widgets/revenue_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Date range ────────────────────────────────────────────────
  late DateTimeRange _dateRange;
  RevenueGrouping _grouping = RevenueGrouping.day;

  // ── State ─────────────────────────────────────────────────────
  bool _loadingChart = true;
  bool _loadingBestSellers = true;
  bool _loadingCategory = true;

  List<RevenueDataPoint> _chartData = [];
  List<BestSellerItem> _bestSellers = [];
  Map<String, double> _categoryRevenue = {};

  // KPI summaries
  double _totalRevenue = 0;
  int _totalOrders = 0;
  double _avgOrderValue = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
    _loadAll();
  }

  // ── Loading ───────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() {
      _loadingChart = true;
      _loadingBestSellers = true;
      _loadingCategory = true;
    });
    await Future.wait([
      _loadChartData(),
      _loadBestSellers(),
      _loadCategoryRevenue(),
    ]);
  }

  Future<List<OrderModel>> _fetchCompletedOrders() async {
    final snap = await _db
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.completed.name)
        .where('createdAt',
            isGreaterThanOrEqualTo: _dateRange.start)
        .where('createdAt',
            isLessThanOrEqualTo:
                _dateRange.end.add(const Duration(days: 1)))
        .get();

    return snap.docs
        .map((d) => OrderModel.fromFirestore(d.id, d.data()))
        .toList();
  }

  Future<void> _loadChartData() async {
    try {
      final orders = await _fetchCompletedOrders();

      // Build buckets
      final Map<String, _Bucket> buckets = {};

      DateTime cursor = _bucketStart(_dateRange.start);
      while (!cursor.isAfter(_dateRange.end)) {
        buckets[_bucketKey(cursor)] = _Bucket(label: _bucketLabel(cursor));
        cursor = _nextBucket(cursor);
      }

      for (final order in orders) {
        final key = _bucketKey(order.createdAt);
        if (buckets.containsKey(key)) {
          buckets[key]!.revenue += order.total;
          buckets[key]!.orderCount++;
        }
      }

      final data = buckets.values
          .map((b) => RevenueDataPoint(
                label: b.label,
                revenue: b.revenue,
                orderCount: b.orderCount,
              ))
          .toList();

      final total = orders.fold<double>(0, (s, o) => s + o.total);

      if (mounted) {
        setState(() {
          _chartData = data;
          _totalRevenue = total;
          _totalOrders = orders.length;
          _avgOrderValue =
              orders.isEmpty ? 0 : total / orders.length;
          _loadingChart = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChart = false);
    }
  }

  Future<void> _loadBestSellers() async {
    try {
      final orders = await _fetchCompletedOrders();

      // Aggregate by product
      final Map<String, _ProductAgg> agg = {};
      for (final order in orders) {
        for (final item in order.items) {
          agg.putIfAbsent(
            item.productId,
            () => _ProductAgg(
                productId: item.productId,
                productName: item.productName),
          );
          agg[item.productId]!.units += item.quantity;
          agg[item.productId]!.revenue += item.totalPrice;
        }
      }

      final sorted = agg.values.toList()
        ..sort((a, b) => b.units.compareTo(a.units));

      final top10 = sorted.take(10).toList();

      if (mounted) {
        setState(() {
          _bestSellers = top10
              .asMap()
              .entries
              .map((e) => BestSellerItem(
                    productId: e.value.productId,
                    productName: e.value.productName,
                    categoryId: '',
                    unitsSold: e.value.units,
                    revenue: e.value.revenue,
                    rank: e.key + 1,
                  ))
              .toList();
          _loadingBestSellers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBestSellers = false);
    }
  }

  Future<void> _loadCategoryRevenue() async {
    try {
      final orders = await _fetchCompletedOrders();

      // Look up category for each product (batch fetch)
      final productIds = orders
          .expand((o) => o.items.map((i) => i.productId))
          .toSet()
          .toList();

      final Map<String, String> productCategory = {};
      const chunk = 30;
      for (int i = 0; i < productIds.length; i += chunk) {
        final slice = productIds.sublist(
            i, i + chunk > productIds.length ? productIds.length : i + chunk);
        final snap = await _db
            .collection('products')
            .where(FieldPath.documentId, whereIn: slice)
            .get();
        for (final doc in snap.docs) {
          productCategory[doc.id] =
              (doc.data()['categoryId'] as String?) ?? 'Other';
        }
      }

      // Fetch category names
      final categoryIds = productCategory.values.toSet().toList();
      final Map<String, String> categoryNames = {};
      for (int i = 0; i < categoryIds.length; i += chunk) {
        final slice = categoryIds.sublist(
            i, i + chunk > categoryIds.length ? categoryIds.length : i + chunk);
        final snap = await _db
            .collection('categories')
            .where(FieldPath.documentId, whereIn: slice)
            .get();
        for (final doc in snap.docs) {
          categoryNames[doc.id] =
              (doc.data()['name'] as String?) ?? doc.id;
        }
      }

      // Aggregate revenue by category
      final Map<String, double> catRevenue = {};
      for (final order in orders) {
        for (final item in order.items) {
          final catId = productCategory[item.productId] ?? 'Other';
          final catName = categoryNames[catId] ?? catId;
          catRevenue[catName] =
              (catRevenue[catName] ?? 0) + item.totalPrice;
        }
      }

      if (mounted) {
        setState(() {
          _categoryRevenue = catRevenue;
          _loadingCategory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCategory = false);
    }
  }

  // ── Bucket helpers ────────────────────────────────────────────

  DateTime _bucketStart(DateTime dt) {
    switch (_grouping) {
      case RevenueGrouping.day:
        return DateTime(dt.year, dt.month, dt.day);
      case RevenueGrouping.week:
        return dt.subtract(Duration(days: dt.weekday - 1));
      case RevenueGrouping.month:
        return DateTime(dt.year, dt.month, 1);
    }
  }

  DateTime _nextBucket(DateTime dt) {
    switch (_grouping) {
      case RevenueGrouping.day:
        return dt.add(const Duration(days: 1));
      case RevenueGrouping.week:
        return dt.add(const Duration(days: 7));
      case RevenueGrouping.month:
        return DateTime(dt.year, dt.month + 1, 1);
    }
  }

  String _bucketKey(DateTime dt) {
    final d = _bucketStart(dt);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _bucketLabel(DateTime dt) {
    switch (_grouping) {
      case RevenueGrouping.day:
        return DateFormat('dd/MM').format(dt);
      case RevenueGrouping.week:
        return 'W${_weekNumber(dt)}';
      case RevenueGrouping.month:
        return DateFormat('MMM').format(dt);
    }
  }

  int _weekNumber(DateTime dt) {
    final firstJan = DateTime(dt.year, 1, 1);
    return ((dt.difference(firstJan).inDays + firstJan.weekday) / 7).ceil();
  }

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: _loadAll,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateFilter(),
            const SizedBox(height: AppSpacing.lg),
            _buildKpiRow(),
            const SizedBox(height: AppSpacing.lg),
            RevenueChart(
              data: _chartData,
              isLoading: _loadingChart,
              grouping: _grouping,
              onGroupingChanged: (g) {
                setState(() => _grouping = g);
                _loadChartData();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 5,
                          child: BestSellersList(
                            items: _bestSellers,
                            isLoading: _loadingBestSellers,
                          )),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                          flex: 4,
                          child: _buildCategoryBreakdown()),
                    ],
                  );
                }
                return Column(
                  children: [
                    BestSellersList(
                        items: _bestSellers,
                        isLoading: _loadingBestSellers),
                    const SizedBox(height: AppSpacing.lg),
                    _buildCategoryBreakdown(),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildOrderVolumeTrend(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range row
          Row(
            children: [
              const Icon(Icons.date_range_outlined,
                  color: AppColors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${DateFormat('MMM d, yyyy').format(_dateRange.start)}'
                  ' – '
                  '${DateFormat('MMM d, yyyy').format(_dateRange.end)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _pickDateRange,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: const BorderSide(color: AppColors.orange),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Change', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quick presets row
          Wrap(
            spacing: 8,
            children: [
              _PresetChip(
                label: 'Today',
                onTap: () => _setPreset(DateTime.now(), DateTime.now()),
              ),
              _PresetChip(
                label: 'This Month',
                onTap: () {
                  final now = DateTime.now();
                  _setPreset(DateTime(now.year, now.month, 1), now);
                },
              ),
              _PresetChip(
                label: 'Last 30 days',
                onTap: () => _setPreset(
                  DateTime.now().subtract(const Duration(days: 30)),
                  DateTime.now(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setPreset(DateTime start, DateTime end) {
    setState(() => _dateRange = DateTimeRange(start: start, end: end));
    _loadAll();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.orange),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadAll();
    }
  }

  Widget _buildKpiRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 800
            ? 3
            : constraints.maxWidth >= 520
                ? 2
                : 1;

        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _KpiCard(
              label: 'Total Revenue',
              value: _loadingChart
                  ? '…'
                  : 'Rs ${_totalRevenue.toStringAsFixed(0)}',
              icon: Icons.currency_rupee,
              color: AppColors.success,
            ),
            _KpiCard(
              label: 'Orders',
              value: _loadingChart ? '…' : '$_totalOrders',
              icon: Icons.receipt_long_outlined,
              color: AppColors.catBlue,
            ),
            _KpiCard(
              label: 'Avg Order Value',
              value: _loadingChart
                  ? '…'
                  : 'Rs ${_avgOrderValue.toStringAsFixed(0)}',
              icon: Icons.trending_up,
              color: AppColors.orange,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryBreakdown() {
    final total = _categoryRevenue.values.fold<double>(0, (s, v) => s + v);
    final sorted = _categoryRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      AppColors.orange,
      AppColors.catBlue,
      AppColors.success,
      AppColors.catPurple,
      AppColors.catPink,
      AppColors.catCyan,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline,
                  color: AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Revenue by Category',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingCategory)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No category data yet',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...sorted.asMap().entries.map((e) {
              final color = colors[e.key % colors.length];
              final pct = total > 0 ? e.value.value / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.value.key,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Text(
                          'Rs ${e.value.value.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMid,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(pct * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: AppColors.bgCreamLight,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOrderVolumeTrend() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_outlined,
                  color: AppColors.catBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Order Volume Trend',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingChart)
            const Center(child: CircularProgressIndicator())
          else if (_chartData.isEmpty ||
              _chartData.every((d) => d.orderCount == 0))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No order volume data yet',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ..._chartData
                .where((d) => d.orderCount > 0)
                .map((d) => _buildVolumeBar(d)),
        ],
      ),
    );
  }

  Widget _buildVolumeBar(RevenueDataPoint d) {
    final max = _chartData.fold<int>(
        0, (m, p) => p.orderCount > m ? p.orderCount : m);
    final fraction = max > 0 ? d.orderCount / max : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              d.label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                backgroundColor: AppColors.bgCreamLight,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.catBlue),
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${d.orderCount}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMid,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Internal helpers ──────────────────────────────────────────

class _Bucket {
  final String label;
  double revenue = 0;
  int orderCount = 0;
  _Bucket({required this.label});
}

class _ProductAgg {
  final String productId;
  final String productName;
  int units = 0;
  double revenue = 0;
  _ProductAgg({required this.productId, required this.productName});
}

// ── Small widgets ─────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bgCreamLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMid,
          ),
        ),
      ),
    );
  }
}