import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/services/auth_service.dart';
import '../../orders/models/order_model.dart';
import '../../payments/models/payment_model.dart';
import '../../products/models/product_model.dart';
import '../widgets/alerts_panel.dart';
import '../widgets/kpi_card.dart';
import '../widgets/recent_orders_widget.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  late Future<_RevenueSnapshot> _revenueFuture;
  String _adminLabel = 'Admin';

  @override
  void initState() {
    super.initState();
    _revenueFuture = _loadRevenue();
    _loadAdminLabel();
  }

  Future<void> _loadAdminLabel() async {
    final email = await _authService.getCurrentAdminEmail();
    if (!mounted) return;
    setState(() => _adminLabel = email ?? 'Admin');
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      context.go('/admin-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth =
                constraints.maxWidth >= 1240 ? 1180.0 : double.infinity;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(context)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate.fixed([
                          _buildKpis(),
                          const SizedBox(height: 18),
                          _buildPrimaryGrid(),
                          const SizedBox(height: 18),
                          _buildAlerts(),
                          const SizedBox(height: 28),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Dashboard',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome, $_adminLabel',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickActionButton(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                onPressed: () => context.push('/admin/analytics'),
              ),
              _QuickActionButton(
                icon: Icons.shopping_bag_outlined,
                label: 'Products',
                onPressed: () => context.push('/admin/products'),
              ),
              _QuickActionButton(
                icon: Icons.receipt_long_outlined,
                label: 'Orders',
                onPressed: () => context.push('/admin/orders'),
              ),
              _QuickActionButton(
                icon: Icons.verified_user_outlined,
                label: 'Payments',
                onPressed: () => context.push('/admin/payments'),
              ),
              _QuickActionButton(
                icon: Icons.inventory_2_outlined,
                label: 'Inventory',
                onPressed: () => context.push('/inventory'),
              ),
              _QuickActionButton(
                icon: Icons.refresh,
                label: 'Refresh',
                onPressed: () {
                  setState(() {
                    _revenueFuture = _loadRevenue();
                  });
                },
              ),
              _QuickActionButton(
                icon: Icons.logout,
                label: 'Logout',
                isDestructive: true,
                onPressed: _logout,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 16),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpis() {
    return FutureBuilder<_RevenueSnapshot>(
      future: _revenueFuture,
      builder: (context, snapshot) {
        final revenue = snapshot.data ?? _RevenueSnapshot.empty();
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.hasError;

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;

            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: columns == 1 ? 2.45 : 1.9,
              children: [
                KpiCard(
                  title: 'Today Revenue',
                  value: error ? '--' : _formatCurrency(revenue.today),
                  subtitle:
                      error ? 'Revenue unavailable' : 'Completed orders today',
                  icon: Icons.today_outlined,
                  color: AppColors.success,
                  isLoading: loading,
                ),
                KpiCard(
                  title: 'This Week',
                  value: error ? '--' : _formatCurrency(revenue.week),
                  subtitle:
                      error ? 'Revenue unavailable' : 'Running weekly total',
                  icon: Icons.calendar_view_week_outlined,
                  color: AppColors.catBlue,
                  isLoading: loading,
                ),
                KpiCard(
                  title: 'This Month',
                  value: error ? '--' : _formatCurrency(revenue.month),
                  subtitle:
                      error ? 'Revenue unavailable' : 'Current month total',
                  icon: Icons.calendar_month_outlined,
                  color: AppColors.orange,
                  isLoading: loading,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPrimaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 940;
        final chart = FutureBuilder<_RevenueSnapshot>(
          future: _revenueFuture,
          builder: (context, snapshot) {
            return _RevenueChart(
              dailyRevenue: snapshot.data?.dailyRevenue ?? const [],
              isLoading: snapshot.connectionState == ConnectionState.waiting,
              error: snapshot.error,
            );
          },
        );

        final recentOrders = StreamBuilder<List<OrderModel>>(
          stream: _watchRecentOrders(),
          builder: (context, snapshot) {
            return RecentOrdersWidget(
              orders: snapshot.data ?? const [],
              isLoading: snapshot.connectionState == ConnectionState.waiting,
              error: snapshot.error,
            );
          },
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: chart),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: recentOrders),
            ],
          );
        }

        return Column(
          children: [
            chart,
            const SizedBox(height: 16),
            recentOrders,
          ],
        );
      },
    );
  }

  Widget _buildAlerts() {
    return StreamBuilder<List<ProductModel>>(
      stream: _watchLowStockProducts(),
      builder: (context, stockSnapshot) {
        return StreamBuilder<List<PaymentModel>>(
          stream: _watchPendingPayments(),
          builder: (context, paymentSnapshot) {
            return AlertsPanel(
              lowStockProducts: stockSnapshot.data ?? const [],
              pendingPayments: paymentSnapshot.data ?? const [],
              isLoadingStock:
                  stockSnapshot.connectionState == ConnectionState.waiting,
              isLoadingPayments:
                  paymentSnapshot.connectionState == ConnectionState.waiting,
              stockError: stockSnapshot.error,
              paymentsError: paymentSnapshot.error,
            );
          },
        );
      },
    );
  }

  Stream<List<OrderModel>> _watchRecentOrders() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(6)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<ProductModel>> _watchLowStockProducts() async* {
    final threshold = await _loadLowStockThreshold();

    yield* _firestore
        .collection('products')
        .where('stock', isLessThanOrEqualTo: threshold)
        .orderBy('stock')
        .limit(8)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<PaymentModel>> _watchPendingPayments() {
    return _firestore
        .collection('payments')
        .where('status', isEqualTo: PaymentStatus.verificationPending.name)
        .orderBy('createdAt', descending: true)
        .limit(8)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<_RevenueSnapshot> _loadRevenue() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final weekStart =
        todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final results = await Future.wait([
      _sumRevenue(todayStart, tomorrowStart),
      _sumRevenue(weekStart, tomorrowStart),
      _sumRevenue(monthStart, nextMonthStart),
      _loadDailyRevenue(
          todayStart.subtract(const Duration(days: 6)), tomorrowStart),
    ]);

    return _RevenueSnapshot(
      today: results[0] as double,
      week: results[1] as double,
      month: results[2] as double,
      dailyRevenue: results[3] as List<_DailyRevenue>,
    );
  }

  Future<double> _sumRevenue(DateTime start, DateTime end) async {
    final snapshot = await _firestore
        .collection('orders')
        .where('status',
            whereIn: [OrderStatus.completed.name, OrderStatus.completed.label])
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .get();

    return snapshot.docs.fold<double>(
      0,
      (total, doc) => total + ((doc.data()['total'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<List<_DailyRevenue>> _loadDailyRevenue(
      DateTime start, DateTime end) async {
    final values = <String, double>{};
    var cursor = DateTime(start.year, start.month, start.day);
    while (cursor.isBefore(end)) {
      values[_dateKey(cursor)] = 0;
      cursor = cursor.add(const Duration(days: 1));
    }

    QuerySnapshot<Map<String, dynamic>>? analytics;
    try {
      analytics = await _firestore
          .collection('analytics')
          .where(FieldPath.documentId, whereIn: values.keys.toList())
          .get();
    } catch (_) {
      analytics = null;
    }

    var hasAnalyticsRevenue = false;
    if (analytics != null) {
      for (final doc in analytics.docs) {
        final data = doc.data();
        final revenue = (data['revenue'] as num?)?.toDouble() ??
            (data['totalRevenue'] as num?)?.toDouble();
        if (revenue != null) {
          hasAnalyticsRevenue = true;
          values[doc.id] = revenue;
        }
      }
    }

    if (hasAnalyticsRevenue) {
      return values.entries
          .map((entry) => _DailyRevenue(
              label: entry.key.substring(5), revenue: entry.value))
          .toList();
    }

    final orders = await _firestore
        .collection('orders')
        .where('status',
            whereIn: [OrderStatus.completed.name, OrderStatus.completed.label])
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .get();

    for (final doc in orders.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null) continue;
      final key = _dateKey(createdAt);
      values[key] =
          (values[key] ?? 0) + ((data['total'] as num?)?.toDouble() ?? 0);
    }

    return values.entries
        .map((entry) =>
            _DailyRevenue(label: entry.key.substring(5), revenue: entry.value))
        .toList();
  }

  Future<int> _loadLowStockThreshold() async {
    final doc =
        await _firestore.collection('app_settings').doc('inventory').get();
    return (doc.data()?['lowStockThreshold'] as num?)?.toInt() ?? 10;
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return 'Rs ${(amount / 100000).toStringAsFixed(2)}L';
    }
    if (amount >= 1000) {
      return 'Rs ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return 'Rs ${amount.toStringAsFixed(0)}';
  }
}

class _RevenueChart extends StatelessWidget {
  final List<_DailyRevenue> dailyRevenue;
  final bool isLoading;
  final Object? error;

  const _RevenueChart({
    required this.dailyRevenue,
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final maxRevenue = dailyRevenue.fold<double>(
      0,
      (max, day) => day.revenue > max ? day.revenue : max,
    );

    return Container(
      height: 360,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Revenue Trend',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Text(
                'Last 7 days',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Builder(
              builder: (context) {
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (error != null) {
                  return _ChartMessage(
                    icon: Icons.error_outline,
                    title: 'Revenue unavailable',
                    subtitle: error.toString(),
                  );
                }
                if (dailyRevenue.isEmpty || maxRevenue == 0) {
                  return const _ChartMessage(
                    icon: Icons.show_chart,
                    title: 'No completed revenue yet',
                    subtitle: 'Completed orders will build this trend.',
                  );
                }

                return LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxRevenue * 1.2,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => const FlLine(
                        color: AppColors.cardBorder,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            if (value == 0 || value == meta.max) {
                              return const SizedBox.shrink();
                            }
                            final label = value >= 1000
                                ? '${(value / 1000).toStringAsFixed(0)}K'
                                : value.toStringAsFixed(0);
                            return Text(
                              label,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= dailyRevenue.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                dailyRevenue[index].label,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < dailyRevenue.length; i++)
                            FlSpot(i.toDouble(), dailyRevenue[i].revenue),
                        ],
                        color: AppColors.orange,
                        barWidth: 3,
                        isCurved: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.orange.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.orange;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.35)),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ChartMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ChartMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textHint, size: 38),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _RevenueSnapshot {
  final double today;
  final double week;
  final double month;
  final List<_DailyRevenue> dailyRevenue;

  const _RevenueSnapshot({
    required this.today,
    required this.week,
    required this.month,
    required this.dailyRevenue,
  });

  factory _RevenueSnapshot.empty() {
    return const _RevenueSnapshot(
      today: 0,
      week: 0,
      month: 0,
      dailyRevenue: [],
    );
  }
}

class _DailyRevenue {
  final String label;
  final double revenue;

  const _DailyRevenue({
    required this.label,
    required this.revenue,
  });
}