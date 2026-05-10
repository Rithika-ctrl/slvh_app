import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../products/models/product_model.dart';
import '../../../core/constants/app_colors.dart';

/// FeaturedProductsGrid
///
/// Displays a 2-column grid of featured/new arrival products
/// from Firestore. Fires [onProductTap] when a card is tapped
/// and [onAddToCart] when the + button is pressed.
class FeaturedProductsGrid extends StatelessWidget {
  final List<ProductModel> products;
  final bool isLoading;
  final ValueChanged<ProductModel>? onProductTap;
  final ValueChanged<ProductModel>? onAddToCart;

  const FeaturedProductsGrid({
    super.key,
    required this.products,
    this.isLoading = false,
    this.onProductTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildSkeletons();
    }

    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No products yet',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) => _ProductCard(
        product: products[i],
        onTap: () => onProductTap?.call(products[i]),
        onAdd: () => onAddToCart?.call(products[i]),
      ),
    );
  }

  Widget _buildSkeletons() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product card
// ─────────────────────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.discountPrice != null;
    final effectivePrice = product.effectivePrice;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB47820).withValues(alpha: 0.09),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ────────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    child: product.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.images.first,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppColors.bgCreamLight,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.orange),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => _NoImage(
                              name: product.name,
                            ),
                          )
                        : _NoImage(name: product.name),
                  ),
                  // Discount badge
                  if (hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${product.discountPercentage?.toInt()}% OFF',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  // Out of stock overlay
                  if (!product.isInStock)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: const Center(
                            child: Text(
                              'OUT OF\nSTOCK',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.unitType,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${effectivePrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (hasDiscount)
                            Text(
                              '₹${product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHint,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (product.isInStock)
                        GestureDetector(
                          onTap: onAdd,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.orangeLight,
                                  AppColors.orange
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.add_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _NoImage extends StatelessWidget {
  final String name;
  const _NoImage({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.bgCreamLight,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCreamLight,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}