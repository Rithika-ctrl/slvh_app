import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// A row of 5 stars.
///
/// When [onChanged] is provided it becomes interactive (tap-to-rate).
/// When [onChanged] is null it renders read-only.
class StarRatingBar extends StatelessWidget {
  final double rating;       // 0.0 – 5.0
  final double starSize;
  final ValueChanged<double>? onChanged; // null → read-only
  final Color filledColor;
  final Color emptyColor;
  final MainAxisAlignment alignment;

  const StarRatingBar({
    Key? key,
    required this.rating,
    this.starSize = 24,
    this.onChanged,
    this.filledColor = Colors.amber,
    this.emptyColor = const Color(0xFFDDDDDD),
    this.alignment = MainAxisAlignment.start,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1.0;
        final filled = rating >= starValue;
        final halfFilled = !filled && rating >= starValue - 0.5;

        final icon = filled
            ? Icons.star_rounded
            : halfFilled
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded;

        final color = (filled || halfFilled) ? filledColor : emptyColor;

        if (onChanged != null) {
          return GestureDetector(
            onTap: () => onChanged!(starValue),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(icon, size: starSize, color: color),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(icon, size: starSize, color: color),
        );
      }),
    );
  }
}

/// Compact rating badge: ⭐ 4.3 (12) — used in ProductCard / ProductDetail.
class RatingBadge extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double fontSize;
  final bool showCount;

  const RatingBadge({
    Key? key,
    required this.rating,
    required this.reviewCount,
    this.fontSize = 11,
    this.showCount = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: fontSize + 2, color: Colors.amber),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        if (showCount) ...[
          const SizedBox(width: 2),
          Text(
            '($reviewCount)',
            style: TextStyle(
              fontSize: fontSize - 1,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}