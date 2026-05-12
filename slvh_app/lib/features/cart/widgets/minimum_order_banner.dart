import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Minimum Order Value Warning Banner
///
/// Displays a warning when cart total is below the minimum order value.
/// Shows the shortfall and encourages adding more items.

class MinimumOrderBanner extends StatelessWidget {
  final double cartTotal;
  final double minOrderValue;
  final VoidCallback? onShoppingContinued;

  const MinimumOrderBanner({
    super.key,
    required this.cartTotal,
    required this.minOrderValue,
    this.onShoppingContinued,
  });

  /// Check if banner should be visible
  bool get shouldShow => minOrderValue > 0 && cartTotal < minOrderValue;

  /// Calculate remaining amount needed
  double get remainingAmount => minOrderValue - cartTotal;

  @override
  Widget build(BuildContext context) {
    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Warning Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                Icons.info_outline,
                color: AppColors.warning,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Minimum Order: ₹${minOrderValue.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add ₹${remainingAmount.toStringAsFixed(0)} more to checkout',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action button
          if (onShoppingContinued != null)
            GestureDetector(
              onTap: onShoppingContinued,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Shop',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
