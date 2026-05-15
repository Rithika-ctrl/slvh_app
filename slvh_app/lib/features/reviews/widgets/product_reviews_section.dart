import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';
import 'star_rating_bar.dart';

/// Displays the rating summary (avg + distribution bar) and a paginated
/// list of individual reviews for a product.
///
/// Drop inside ProductDetailScreen:
/// ```dart
/// ProductReviewsSection(productId: product.id)
/// ```
class ProductReviewsSection extends StatefulWidget {
  final String productId;
  final double? avgRating;
  final int? reviewCount;

  const ProductReviewsSection({
    Key? key,
    required this.productId,
    this.avgRating,
    this.reviewCount,
  }) : super(key: key);

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  final _service = ReviewService();
  static const _pageSize = 5;
  int _visibleCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewModel>>(
      stream: _service.watchProductReviews(widget.productId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final reviews = snapshot.data ?? [];
        final count = reviews.length;
        final avg = count == 0
            ? 0.0
            : reviews.map((r) => r.rating).reduce((a, b) => a + b) / count;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ───────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'RATINGS & REVIEWS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (count == 0)
              _buildEmptyState()
            else ...[
              // ── Summary card ───────────────────────────────────────
              _buildSummaryCard(reviews, avg, count),
              const SizedBox(height: 16),

              // ── Individual reviews ─────────────────────────────────
              ...reviews.take(_visibleCount).map((r) => _ReviewTile(review: r)),

              if (count > _visibleCount)
                Center(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _visibleCount += _pageSize),
                    child: Text(
                      'Show more reviews (${count - _visibleCount} remaining)',
                      style: const TextStyle(color: AppColors.orange),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.bgCreamLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: const [
            Icon(Icons.star_outline_rounded,
                size: 40, color: AppColors.textHint),
            SizedBox(height: 8),
            Text(
              'No reviews yet',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMid),
            ),
            SizedBox(height: 4),
            Text(
              'Be the first to review this product!',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      );

  Widget _buildSummaryCard(
      List<ReviewModel> reviews, double avg, int count) {
    // Build distribution: count of each star (5 down to 1)
    final dist = List.generate(5, (i) {
      final star = 5 - i;
      return reviews.where((r) => r.rating.round() == star).length;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Big avg number
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              StarRatingBar(rating: avg, starSize: 16),
              const SizedBox(height: 4),
              Text(
                '$count ${count == 1 ? 'review' : 'reviews'}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Distribution bars
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final barCount = dist[i];
                final fraction = count == 0 ? 0.0 : barCount / count;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$star',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMid,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded,
                          size: 11, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 8,
                            backgroundColor:
                                AppColors.bgCreamLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.amber),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 22,
                        child: Text(
                          '$barCount',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single review tile ──────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;

  const _ReviewTile({Key? key, required this.review}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final masked = _maskPhone(review.userId);
    final date = DateFormat('dd MMM yyyy').format(review.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    masked.isNotEmpty ? masked[0] : '?',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(masked,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        )),
                    Text(date,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              StarRatingBar(rating: review.rating, starSize: 14),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMid, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  /// Mask phone: +919876543210 → +91 98765*****
  String _maskPhone(String phone) {
    if (phone.length < 5) return phone;
    final visible = phone.substring(0, phone.length - 5);
    return '$visible*****';
  }
}