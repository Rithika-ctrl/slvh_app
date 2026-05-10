import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/shop_status_banner.dart';
import '../../auth/services/auth_service.dart';
import '../../banners/widgets/banner_carousel.dart';
import '../../cart/providers/cart_provider.dart';
import '../../categories/services/category_service.dart';
import '../../categories/models/category_model.dart';
import '../../products/models/product_model.dart';
import '../../products/services/product_service.dart';
import '../widgets/category_row.dart';
import '../widgets/featured_products_grid.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final CategoryService _categoryService = CategoryService();
  final ProductService _productService = ProductService();

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  bool _loadingProducts = true;
  String? _userPhone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final phone = await _authService.getCurrentUserPhone();
    final cats = await _categoryService.getAllCategories();
    final prods = await _productService.getAllProducts(onlyActive: true);

    if (!mounted) return;
    setState(() {
      _userPhone = phone ?? 'Shopper';
      _categories = cats;
      _products = prods;
      _loadingProducts = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _loadingProducts = true);
    await _load();
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) return;
    context.push('/products?q=${Uri.encodeComponent(query.trim())}');
  }

  void _onCategoryTap(CategoryModel cat) {
    context.push('/products?categoryId=${cat.id}&categoryName=${Uri.encodeComponent(cat.name)}');
  }

  void _onProductTap(ProductModel p) {
    context.push('/products/${p.id}', extra: p);
  }

  void _onAddToCart(ProductModel p) {
    final cart = context.read<CartProvider>();
    cart.addToCart(p);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${p.name} added to cart 🛒'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _logout() async {
    await _authService.signOut();
    if (mounted) context.go('/');
  }

  // ── Greeting ──────────────────────────────────────────────────────────────

  String get _greeting {
    final h = TimeOfDay.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cartCount =
        context.watch<CartProvider>().totalUnits;

    return GradientBackground(
      child: RefreshIndicator(
        color: AppColors.orange,
        backgroundColor: Colors.white,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App bar ──────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildAppBar(cartCount)),

            // ── Search bar ────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildSearchBar()),

            // ── Shop status ───────────────────────────────────────────────
            const SliverToBoxAdapter(child: ShopStatusBanner()),

            // ── Banner carousel ───────────────────────────────────────────
            const SliverToBoxAdapter(child: BannerCarousel()),

            // ── Categories ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'Shop by Category',
                color: AppColors.orange,
                onSeeAll: () => context.push('/products'),
              ),
            ),
            SliverToBoxAdapter(child: _buildCategories()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Featured products ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'Featured Products',
                color: AppColors.catPink,
                onSeeAll: () => context.push('/products'),
              ),
            ),
            SliverToBoxAdapter(
              child: FeaturedProductsGrid(
                products: _products.take(6).toList(),
                isLoading: _loadingProducts,
                onProductTap: _onProductTap,
                onAddToCart: _onAddToCart,
              ),
            ),

            // ── New arrivals ──────────────────────────────────────────────
            if (!_loadingProducts && _products.length > 6) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  'New Arrivals',
                  color: AppColors.catBlue,
                  onSeeAll: () => context.push('/products'),
                ),
              ),
              SliverToBoxAdapter(
                child: FeaturedProductsGrid(
                  products: _products.skip(6).take(6).toList(),
                  onProductTap: _onProductTap,
                  onAddToCart: _onAddToCart,
                ),
              ),
            ],

            // ── Why shop with us ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'Why Shop with Us',
                color: AppColors.catGreen,
              ),
            ),
            SliverToBoxAdapter(child: _buildPromoStrip()),

            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(int cartCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFB347), AppColors.orange]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child:
                const Center(child: Text('👤', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting.toUpperCase()} 👋',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHint,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  _userPhone ?? 'Shopper',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Notifications
          _IconPill(
            emoji: '🔔',
            gradient: const [Color(0xFFB8E6FF), Color(0xFF74B9FF)],
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(width: 8),
          // Cart
          _IconPill(
            emoji: '🛍️',
            gradient: const [Color(0xFFFFEAA7), Color(0xFFFDCB6E)],
            badge: cartCount > 0 ? '$cartCount' : null,
            onTap: () => context.push('/cart'),
          ),
          const SizedBox(width: 8),
          // Orders
          _IconPill(
            emoji: '📦',
            gradient: const [Color(0xFFC8F5E8), Color(0xFF55EFC4)],
            onTap: () => context.push('/orders'),
          ),
          const SizedBox(width: 8),
          // Logout
          _IconPill(
            emoji: '↩',
            gradient: const [Color(0xFFFAB1A0), Color(0xFFE17055)],
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        showSearch(
          context: context,
          delegate: _ProductSearchDelegate(onSearch: _onSearch),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: const Color(0x2FDCA03C), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB47820).withValues(alpha: 0.09),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Search groceries & more…',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF9F43), AppColors.orange]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Search',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
    String title, {
    Color color = AppColors.orange,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'See all →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Widget _buildCategories() {
    if (_categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'No categories yet',
          style: TextStyle(color: AppColors.textHint, fontSize: 13),
        ),
      );
    }
    return CategoryRow(
      categories: _categories,
      onCategoryTap: _onCategoryTap,
    );
  }

  // ── Promo strip ───────────────────────────────────────────────────────────

  Widget _buildPromoStrip() {
    final promos = [
      {
        'emoji': '🚀',
        'title': 'Express Pickup',
        'sub': 'Book a slot',
        'titleColor': AppColors.catPurple,
        'subColor': AppColors.textHint,
      },
      {
        'emoji': '🆓',
        'title': 'Free Delivery',
        'sub': 'Orders ₹299+',
        'titleColor': AppColors.success,
        'subColor': AppColors.textHint,
      },
      {
        'emoji': '✨',
        'title': 'New Arrivals',
        'sub': '50+ products',
        'titleColor': AppColors.catYellow,
        'subColor': AppColors.textHint,
      },
    ];

    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 8),
        itemCount: promos.length,
        itemBuilder: (_, i) {
          final p = promos[i];
          return Container(
            width: 158,
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0x25DCA03C), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(0xFFB47820).withValues(alpha: 0.09),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(p['emoji'] as String,
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p['title'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: p['titleColor'] as Color,
                        ),
                      ),
                      Text(
                        p['sub'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: p['subColor'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon pill
// ─────────────────────────────────────────────────────────────────────────────

class _IconPill extends StatelessWidget {
  final String emoji;
  final List<Color> gradient;
  final String? badge;
  final VoidCallback? onTap;

  const _IconPill({
    required this.emoji,
    required this.gradient,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 17)),
            ),
          ),
          if (badge != null)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search delegate
// ─────────────────────────────────────────────────────────────────────────────

class _ProductSearchDelegate extends SearchDelegate<String> {
  final ValueChanged<String> onSearch;

  _ProductSearchDelegate({required this.onSearch});

  @override
  String get searchFieldLabel => 'Search products…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgCream,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.textHint),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isNotEmpty) {
      onSearch(query.trim());
      close(context, query.trim());
    }
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = [
      'Rice', 'Dal', 'Oil', 'Soap', 'Shampoo', 'Flour', 'Sugar', 'Salt',
    ].where((s) => s.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suggestions.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.search_rounded, color: AppColors.textHint),
        title: Text(
          suggestions[i],
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        onTap: () {
          query = suggestions[i];
          showResults(context);
        },
      ),
    );
  }
}