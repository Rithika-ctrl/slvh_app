import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class BestSellerItem {
  final String productId;
  final String productName;
  final String categoryId;
  final int unitsSold;
  final double revenue;
  final int rank;

  const BestSellerItem({
    required this.productId,
    required this.productName,
    required this.categoryId,
    required this.unitsSold,
    required this.revenue,
    required this.rank,
  });
}

class BestSellersList extends StatelessWidget {
  final List<BestSellerItem> items;
  final bool isLoading;

  const BestSellersList({
    super.key,
    required this.items,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.emoji_events_outlined,
                  color: AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Best Sellers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
              ),
              const Spacer(),
              Text(
                'by units sold',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (items.isEmpty)
            _buildEmpty()
          else
            ...items.map((item) => _buildRow(context, item)),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, BestSellerItem item) {
    final maxUnits =
        items.isNotEmpty ? items.first.unitsSold.toDouble() : 1.0;
    final fraction = maxUnits > 0 ? item.unitsSold / maxUnits : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rankColor(item.rank).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${item.rank}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _rankColor(item.rank),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.unitsSold} units',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.bgCreamLight,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _rankColor(item.rank),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs ${item.revenue.toStringAsFixed(0)} revenue',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined,
                size: 36, color: AppColors.textHint),
            const SizedBox(height: 8),
            Text(
              'No sales data yet',
              style: TextStyle(
                  color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFB300); // gold
      case 2:
        return const Color(0xFF90A4AE); // silver
      case 3:
        return const Color(0xFFBF8970); // bronze
      default:
        return AppColors.catBlue;
    }
  }
}