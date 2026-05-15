import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../orders/models/order_model.dart';
import '../services/review_service.dart';
import 'star_rating_bar.dart';

/// Prompts the customer to rate every un-reviewed product from a completed
/// order.  Shows one product at a time with a pager; dismisses when done.
///
/// Usage:
/// ```dart
/// RatingDialog.show(context, order: order, userId: phone);
/// ```
class RatingDialog extends StatefulWidget {
  final OrderModel order;
  final String userId;
  final List<String> unratedProductIds;

  const RatingDialog._({
    Key? key,
    required this.order,
    required this.userId,
    required this.unratedProductIds,
  }) : super(key: key);

  /// Shows the dialog only if the order is completed and has un-reviewed items.
  /// Returns immediately (no-op) if nothing to review.
  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    required String userId,
  }) async {
    if (order.status != OrderStatus.completed) return;

    final service = ReviewService();
    final ratedIds = await service.getRatedProductIds(order.id);
    final unrated = order.items
        .where((item) => !ratedIds.contains(item.productId))
        .map((item) => item.productId)
        .toList();

    if (unrated.isEmpty) return;
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog._(
        order: order,
        userId: userId,
        unratedProductIds: unrated,
      ),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  final _reviewService = ReviewService();
  int _currentIndex = 0;
  double _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  OrderItem get _currentItem => widget.order.items.firstWhere(
        (i) => i.productId == widget.unratedProductIds[_currentIndex],
      );

  bool get _isLast =>
      _currentIndex == widget.unratedProductIds.length - 1;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await _reviewService.submitReview(
        productId: _currentItem.productId,
        userId: widget.userId,
        orderId: widget.order.id,
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      if (_isLast) {
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _currentIndex++;
          _rating = 0;
          _commentController.clear();
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
        setState(() => _submitting = false);
      }
    }
  }

  void _skip() {
    if (_isLast) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _currentIndex++;
        _rating = 0;
        _commentController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.unratedProductIds.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.bgCream,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: AppColors.orange, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rate Your Purchase',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (total > 1)
                        Text(
                          'Item ${_currentIndex + 1} of $total',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                // Skip / close
                GestureDetector(
                  onTap: _skip,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close,
                        size: 18, color: AppColors.textMid),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Product name ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                _currentItem.productName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),

            // ── Star selector ────────────────────────────────────────
            StarRatingBar(
              rating: _rating,
              starSize: 38,
              alignment: MainAxisAlignment.center,
              onChanged: (v) => setState(() => _rating = v),
            ),

            const SizedBox(height: 8),

            Text(
              _ratingLabel(_rating),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _rating > 0 ? AppColors.orange : AppColors.textHint,
              ),
            ),

            const SizedBox(height: 16),

            // ── Comment ──────────────────────────────────────────────
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Share your experience (optional)…',
                hintStyle: const TextStyle(
                    color: AppColors.textHint, fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.orange),
                ),
                counterStyle:
                    const TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
            ),

            const SizedBox(height: 16),

            // ── Progress dots ─────────────────────────────────────────
            if (total > 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentIndex ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= _currentIndex
                          ? AppColors.orange
                          : AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],

            // ── Submit button ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isLast ? 'Submit Review' : 'Next →',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: _skip,
              child: Text(
                _isLast ? 'Skip & Close' : 'Skip this item',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(double r) {
    if (r == 0) return 'Tap to rate';
    if (r <= 1) return '😞 Poor';
    if (r <= 2) return '😐 Fair';
    if (r <= 3) return '🙂 Good';
    if (r <= 4) return '😊 Very Good';
    return '🤩 Excellent!';
  }
}