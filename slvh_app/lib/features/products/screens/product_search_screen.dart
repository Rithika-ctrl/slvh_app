import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../widgets/product_card.dart';

/// Product Search Screen
///
/// Dedicated search screen with real-time Firestore search.
/// Uses optimized searchProductsOptimized() with name_lowercase field.
/// Features:
/// - Real-time search with StreamBuilder
/// - Efficient Firestore indexing
/// - Case-insensitive prefix matching
/// - Empty state handling

class ProductSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const ProductSearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final ProductService _productService = ProductService();
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _searchQuery = widget.initialQuery ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          title: const Text(
            '🔍 Search Products',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          centerTitle: true,
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
        ),
        body: Column(
          children: [
            // ── Search Input ────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: 'Type product name…',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.95),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: AppColors.orange,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: AppColors.orange.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: AppColors.orange,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      Icons.search,
                      color: AppColors.orange,
                      size: 20,
                    ),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.close,
                              color: AppColors.textHint,
                              size: 18,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // ── Search Results ──────────────────────────────────────
            if (_searchQuery.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 64,
                        color: AppColors.orange.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Start typing to search',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: StreamBuilder<List<ProductModel>>(
                  stream: _productService.searchProductsOptimized(_searchQuery),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.orange.withOpacity(0.7),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red.withOpacity(0.6),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Error loading search results',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final products = snapshot.data ?? [];

                    if (products.isEmpty) {
                      return EmptyStateWidget(
                        icon: Icons.shopping_bag_outlined,
                        title: 'No products found',
                        subtitle: 'No results for "$_searchQuery"',
                        iconColor: AppColors.orange.withOpacity(0.35),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        return ProductCard(
                          product: products[index],
                          onTap: () {
                            context.push(
                              '/product/${products[index].id}',
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
