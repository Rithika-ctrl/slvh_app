import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

enum RevenueGrouping { day, week, month }

class RevenueDataPoint {
  final String label;
  final double revenue;
  final int orderCount;

  const RevenueDataPoint({
    required this.label,
    required this.revenue,
    required this.orderCount,
  });
}

class RevenueChart extends StatefulWidget {
  final List<RevenueDataPoint> data;
  final bool isLoading;
  final RevenueGrouping grouping;
  final ValueChanged<RevenueGrouping> onGroupingChanged;

  const RevenueChart({
    super.key,
    required this.data,
    required this.isLoading,
    required this.grouping,
    required this.onGroupingChanged,
  });

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final maxRevenue = widget.data.fold<double>(
      0,
      (m, d) => d.revenue > m ? d.revenue : m,
    );

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
          _buildHeader(context),
          const SizedBox(height: 20),
          SizedBox(
            height: 260,
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.data.isEmpty || maxRevenue == 0
                    ? _buildEmptyState()
                    : _buildChart(maxRevenue),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revenue Trend',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
              ),
              Text(
                _groupingLabel(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
        ),
        // Grouping toggle
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCreamLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: RevenueGrouping.values.map((g) {
              final selected = widget.grouping == g;
              return GestureDetector(
                onTap: () => widget.onGroupingChanged(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    _groupingShortLabel(g),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildChart(double maxRevenue) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxRevenue * 1.25,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.cardBorder,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            setState(() {
              _touchedIndex =
                  response?.lineBarSpots?.first.spotIndex;
            });
          },
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.textDark,
            getTooltipItems: (spots) => spots.map((spot) {
              final pt = widget.data[spot.spotIndex];
              return LineTooltipItem(
                'Rs ${pt.revenue.toStringAsFixed(0)}\n${pt.orderCount} orders',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
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
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: widget.data.length > 10
                  ? (widget.data.length / 7).ceilToDouble()
                  : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= widget.data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    widget.data[index].label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
              for (var i = 0; i < widget.data.length; i++)
                FlSpot(i.toDouble(), widget.data[i].revenue),
            ],
            color: AppColors.orange,
            barWidth: 2.5,
            isCurved: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, index) => FlDotCirclePainter(
                radius: index == _touchedIndex ? 6 : 3.5,
                color: AppColors.orange,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.orange.withOpacity(0.18),
                  AppColors.orange.withOpacity(0.01),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 44, color: AppColors.textHint),
          const SizedBox(height: 10),
          Text(
            'No revenue data yet',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Completed orders will appear here.',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _groupingLabel() {
    switch (widget.grouping) {
      case RevenueGrouping.day:
        return 'Last 30 days';
      case RevenueGrouping.week:
        return 'Last 12 weeks';
      case RevenueGrouping.month:
        return 'Last 12 months';
    }
  }

  String _groupingShortLabel(RevenueGrouping g) {
    switch (g) {
      case RevenueGrouping.day:
        return 'Day';
      case RevenueGrouping.week:
        return 'Week';
      case RevenueGrouping.month:
        return 'Month';
    }
  }
}