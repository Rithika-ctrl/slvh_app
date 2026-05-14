import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Product Detail Screen
/// 
/// Displays detailed product information with real-time stock updates.
/// Features image gallery, descriptions, and add to cart functionality.

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final ProductModel? initialProduct;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();
  late PageController _imageController;
  int _currentImageIndex = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back, color: AppColors.orange),
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Shared to clipboard')),
                  );
                },
                child: const Icon(Icons.share, color: AppColors.orange),
              ),
            ),
          ],
        ),
        body: StreamBuilder<ProductModel?>(
          stream: _productService.watchProduct(widget.productId),
          initialData: widget.initialProduct,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Text('Product not found'),
              );
            }

            final product = snapshot.data!;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image Gallery ──────────────────────────────────
                  _buildImageGallery(product),

                  // ── Product Info ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Brand and Category
                        Text(
                          product.unitType,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Rating
                        if (product.rating != null)
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (index) => Icon(
                                  Icons.star,
                                  size: 16,
                                  color: index < product.rating!.toInt()
                                      ? Colors.amber
                                      : Colors.grey[300],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${product.rating!.toStringAsFixed(1)} (${product.reviewCount ?? 0} reviews)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),

                        // ── Price Section ──────────────────────────────
                        _buildPriceSection(product),

                        const SizedBox(height: 20),

                        // ── Stock Status (Real-time) ───────────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: product.isInStock
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: product.isInStock
                                  ? Colors.green
                                  : Colors.red,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                product.isInStock
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: product.isInStock
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.isInStock
                                          ? 'In Stock'
                                          : 'Out of Stock',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: product.isInStock
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    if (product.isInStock)
                                      Text(
                                        '${product.stock} items available',
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
                        ),

                        const SizedBox(height: 20),

                        // ── Description ────────────────────────────────
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          product.description,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Quantity Selector ──────────────────────────
                        _buildQuantitySelector(product),

                        // ── Max Order Qty Warning ──────────────────────
                        if (product.maxOrderQty != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withOpacity(0.1),
                                border: Border.all(
                                  color: AppColors.orange.withOpacity(0.5),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outlined,
                                    size: 16,
                                    color: AppColors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Maximum ${product.maxOrderQty} units per order',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.orange.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // ── Add to Cart Button ────────────────────────
                        _buildAddToCartButton(product),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build image gallery with page indicator
  Widget _buildImageGallery(ProductModel product) {
    return Stack(
      children: [
        // Images
        SizedBox(
          height: 300,
          child: product.images.isEmpty
              ? Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _imageController,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                  },
                  itemCount: product.images.length,
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: product.images[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.orange,
                              ),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    );
                  },
                ),
        ),

        // Page Indicator (Bottom Center)
        if (product.images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${product.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),

        // Discount Badge
        if (product.discountPrice != null)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                '${product.discountPercentage?.toInt() ?? 0}% OFF',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build price section
  Widget _buildPriceSection(ProductModel product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Current Price
            Text(
              '₹${product.effectivePrice.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.orange,
              ),
            ),

            const SizedBox(width: 12),

            // Original Price
            if (product.discountPrice != null) ...[
              Text(
                '₹${product.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Save ₹${(product.price - product.discountPrice!).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Build quantity selector
  Widget _buildQuantitySelector(ProductModel product) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.orange.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Quantity:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              if (_quantity > 1) {
                setState(() => _quantity--);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.remove, size: 18, color: AppColors.orange),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$_quantity',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              final maxQty = product.maxOrderQty;
              if (maxQty != null && _quantity >= maxQty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Max order quantity is $maxQty'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else {
                setState(() => _quantity++);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: product.maxOrderQty != null && _quantity >= product.maxOrderQty!
                    ? Colors.grey.withOpacity(0.2)
                    : AppColors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.add,
                size: 18,
                color: product.maxOrderQty != null && _quantity >= product.maxOrderQty!
                    ? Colors.grey
                    : AppColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build add to cart button
  Widget _buildAddToCartButton(ProductModel product) {
    final isOutOfStock = !product.isInStock;
    final exceedsMaxQty = product.maxOrderQty != null && _quantity > product.maxOrderQty!;

    return GestureDetector(
      onTap: isOutOfStock || exceedsMaxQty
          ? null
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ ${product.name} × $_quantity added to cart',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isOutOfStock || exceedsMaxQty
              ? LinearGradient(
                  colors: [Colors.grey[400]!, Colors.grey[500]!],
                )
              : const LinearGradient(
                  colors: [Color(0xFFFF9F43), AppColors.orange],
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isOutOfStock || exceedsMaxQty
              ? []
              : [
                  BoxShadow(
                    color: AppColors.orange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            isOutOfStock
                ? 'Out of Stock'
                : exceedsMaxQty
                    ? 'Max: ${product.maxOrderQty} units'
                    : 'Add to Cart',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}