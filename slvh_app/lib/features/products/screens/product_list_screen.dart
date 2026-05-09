import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../categories/models/category_model.dart';
import '../../categories/services/category_service.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../widgets/product_card.dart';
import '../widgets/search_bar.dart';

/// Product List Screen
///
/// Displays products with search and category filter capabilities.
/// Features real-time stock updates via StreamBuilder.

class ProductListScreen extends StatefulWidget {
  final String? categoryId;

  const ProductListScreen({
    super.key,
    this.categoryId,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();

  String _searchQuery = '';
  String? _selectedCategoryId;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectedCategoryId = widget.categoryId;
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
            '🛍️ Shop Products',
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
            // ── Search Bar ─────────────────────────────────────────
            ProductSearchBar(
              placeholder: 'Search products…',
              onSearch: (query) {
                setState(() => _searchQuery = query);
              },
              onFilterTap: _selectedCategoryId == null
                  ? null
                  : () {
                      setState(() => _selectedCategoryId = null);
                    },
            ),

            // ── Category Filter ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                height: 40,
                child: FutureBuilder<List<CategoryModel>>(
                  future: _categoryService.getAllCategories(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final categories = snapshot.data!;

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length + 1,
                      itemBuilder: (context, index) {
                        // "All" button
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedCategoryId = null);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedCategoryId == null
                                      ? AppColors.orange
                                      : Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.orange,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  'All',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedCategoryId == null
                                        ? Colors.white
                                        : AppColors.orange,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final category = categories[index - 1];
                        final isSelected = _selectedCategoryId == category.id;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedCategoryId = category.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.orange
                                    : Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.orange,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.orange,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // ── Products Grid (Real-time with StreamBuilder) ───────
            Expanded(
              child: _buildProductsStream(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build products stream with search and filter
  Widget _buildProductsStream() {
    if (_selectedCategoryId != null) {
      // Products by category with search
      return StreamBuilder<List<ProductModel>>(
        stream: _productService.searchProductsByCategory(
          categoryId: _selectedCategoryId!,
          searchQuery: _searchQuery,
        ),
        builder: (context, snapshot) {
          return _buildProductsGrid(snapshot);
        },
      );
    } else {
      // All products with search
      return FutureBuilder<List<ProductModel>>(
        future: _productService.searchProducts(_searchQuery),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return _buildEmptyState();
          }

          return _buildGridLayout(products);
        },
      );
    }
  }

  /// Build grid from stream snapshot
  Widget _buildProductsGrid(AsyncSnapshot<List<ProductModel>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Text('Error: ${snapshot.error}'),
      );
    }

    final products = snapshot.data ?? [];

    if (products.isEmpty) {
      return _buildEmptyState();
    }

    return _buildGridLayout(products);
  }

  /// Build grid layout
  Widget _buildGridLayout(List<ProductModel> products) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.5,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];

        return ProductCard(
          product: product,
          onTap: () {
            // Navigate to product detail
            context.push('/product/${product.id}', extra: product);
          },
          onAddToCart: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ ${product.name} added to cart'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  /// Empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _searchQuery.isEmpty ? '📦' : '🔍',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No products found'
                : 'No products matching "$_searchQuery"',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
