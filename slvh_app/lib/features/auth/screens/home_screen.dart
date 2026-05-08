import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  String? _userPhone;

  // Offer banner data
  int _offerIndex = 0;
  final List<Map<String, dynamic>> _offers = [
    {
      'pct': '20% OFF',
      'desc': 'On all cleaning products',
      'emoji': '🧹',
      'colors': [Color(0xFFFF9F43), Color(0xFFE07800)],
      'ctaColor': Color(0xFFE07800),
    },
    {
      'pct': 'BUY 2 GET 1',
      'desc': 'Personal care range',
      'emoji': '🧴',
      'colors': [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
      'ctaColor': Color(0xFF6C5CE7),
    },
    {
      'pct': '₹50 CASHBACK',
      'desc': 'Orders above ₹500',
      'emoji': '💰',
      'colors': [Color(0xFFFD79A8), Color(0xFFE84393)],
      'ctaColor': Color(0xFFE84393),
    },
  ];

  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
    _startOfferCycle();
  }

  Future<void> _loadUserPhone() async {
    final phone = await _authService.getCurrentUserPhone();
    setState(() {
      _userPhone = phone ?? 'Shopper';
    });
  }

  void _startOfferCycle() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _offerIndex = (_offerIndex + 1) % _offers.length);
      _startOfferCycle();
    });
  }

  void _addToCart(String emoji) {
    setState(() => _cartCount++);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$emoji Added to cart!  🛒 $_cartCount'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _logout() async {
    await _authService.signOut();
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildAppBar()),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildOfferBanner()),
          SliverToBoxAdapter(child: _buildSectionHeader('Shop by Category', '🟠', color: AppColors.orange)),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildSectionHeader('Top Picks', '🩷', color: AppColors.catPink)),
          SliverToBoxAdapter(child: _buildProductGrid()),
          SliverToBoxAdapter(child: _buildSectionHeader('Quick Actions', '💚', color: AppColors.catGreen)),
          SliverToBoxAdapter(child: _buildQuickActions()),
          SliverToBoxAdapter(child: _buildSectionHeader('Why Shop with Us', '💙', color: AppColors.catBlue)),
          SliverToBoxAdapter(child: _buildPromoStrip()),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB347), AppColors.orange],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(child: Text('👤', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GOOD MORNING 👋',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHint,
                    letterSpacing: 1,
                  ),
                ),
                const Text(
                  'Hey, Shopper!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Cart
          _IconPill(
            emoji: '🛍️',
            gradient: const [Color(0xFFFFEAA7), Color(0xFFFDCB6E)],
            badge: _cartCount > 0 ? '$_cartCount' : null,
          ),
          const SizedBox(width: 8),
          // Logout
          GestureDetector(
            onTap: _logout,
            child: _IconPill(
              emoji: '↩',
              gradient: const [Color(0xFFFAB1A0), Color(0xFFE17055)],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB47820).withOpacity(0.09),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0x2FDCA03C),
          width: 1.5,
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9F43), AppColors.orange],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Filter',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Offer banner ───────────────────────────────────────────────────────────
  Widget _buildOfferBanner() {
    final offer = _offers[_offerIndex];
    final colors = offer['colors'] as List<Color>;

    return GestureDetector(
      onTap: () => setState(
          () => _offerIndex = (_offerIndex + 1) % _offers.length),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.38),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background circle decoration
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer['pct'] as String,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offer['desc'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.88),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          'Shop Now →',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: offer['ctaColor'] as Color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  offer['emoji'] as String,
                  style: const TextStyle(fontSize: 58),
                ),
              ],
            ),
            // Dots
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _offers.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: i == _offerIndex ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _offerIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, String dotEmoji,
      {Color color = AppColors.orange}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
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
          Text(
            'See all →',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,

            ),
          ),
        ],
      ),
    );
  }

  // ── Categories ─────────────────────────────────────────────────────────────
  Widget _buildCategories() {
    final cats = [
      {'icon': '🧴', 'name': 'Personal\nCare', 'colors': [const Color(0xFF74B9FF), const Color(0xFF0984E3)], 'textColor': const Color(0xFF0984E3)},
      {'icon': '🧼', 'name': 'Soaps &\nWash',  'colors': [const Color(0xFFFD79A8), const Color(0xFFE84393)], 'textColor': const Color(0xFFE84393)},
      {'icon': '🧹', 'name': 'Cleaning',       'colors': [const Color(0xFF55EFC4), const Color(0xFF00B894)], 'textColor': const Color(0xFF00B894)},
      {'icon': '🧻', 'name': 'Paper',           'colors': [const Color(0xFFFFEAA7), const Color(0xFFFDCB6E)], 'textColor': const Color(0xFFE17055)},
      {'icon': '🫙', 'name': 'Kitchen',         'colors': [const Color(0xFFA29BFE), const Color(0xFF6C5CE7)], 'textColor': const Color(0xFF6C5CE7)},
      {'icon': '🪥', 'name': 'Dental',          'colors': [const Color(0xFFFAB1A0), const Color(0xFFE17055)], 'textColor': const Color(0xFFE17055)},
      {'icon': '🧃', 'name': 'Beverages',       'colors': [const Color(0xFF81ECEC), const Color(0xFF00CEC9)], 'textColor': const Color(0xFF00CEC9)},
      {'icon': '📦', 'name': 'Packaged',        'colors': [const Color(0xFFFDCB6E), const Color(0xFFE17055)], 'textColor': const Color(0xFFE17055)},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 8, bottom: 6),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final cat = cats[i];
          final colors = cat['colors'] as List<Color>;
          return GestureDetector(
            onTap: () {},
            child: Container(
              width: 74,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.55),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.last.withOpacity(0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        cat['icon'] as String,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    cat['name'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: cat['textColor'] as Color,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Product grid ───────────────────────────────────────────────────────────
  Widget _buildProductGrid() {
    final products = [
      {
        'emoji': '🧴', 'name': 'Dettol Handwash', 'brand': 'Dettol · 250ml',
        'price': '₹89', 'badge': 'Best Seller', 'badgeBg': const Color(0xFFFFF4E6),
        'badgeColor': AppColors.orange,
        'btnColors': [const Color(0xFFFF9F43), AppColors.orange],
      },
      {
        'emoji': '🧼', 'name': 'Dove Bar Soap', 'brand': 'Dove · 3×75g',
        'price': '₹120', 'badge': 'New', 'badgeBg': const Color(0xFFFFF0FA),
        'badgeColor': const Color(0xFFE84393),
        'btnColors': [const Color(0xFFFD79A8), const Color(0xFFE84393)],
      },
      {
        'emoji': '🧹', 'name': 'Floor Cleaner', 'brand': 'Harpic · 1L',
        'price': '₹65', 'badge': '20% Off', 'badgeBg': const Color(0xFFE6FFF9),
        'badgeColor': AppColors.success,
        'btnColors': [const Color(0xFF55EFC4), AppColors.success],
      },
      {
        'emoji': '🧃', 'name': 'Real Juice Pack', 'brand': 'Real · 1L × 3',
        'price': '₹210', 'badge': 'Hot Deal', 'badgeBg': const Color(0xFFFFF8E6),
        'badgeColor': const Color(0xFFE17055),
        'btnColors': [const Color(0xFFFFEAA7), const Color(0xFFFDCB6E)],
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: products.length,
        itemBuilder: (_, i) => _ProductCard(
          product: products[i],
          onAdd: () => _addToCart(products[i]['emoji'] as String),
        ),
      ),
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      {'emoji': '🗂️', 'label': 'Browse\nAll',    'colors': [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)]},
      {'emoji': '📍', 'label': 'Near\nMe',        'colors': [AppColors.success, const Color(0xFF55EFC4)]},
      {'emoji': '🚚', 'label': 'Track\nOrder',    'colors': [const Color(0xFFFDCB6E), const Color(0xFFE17055)]},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: actions.map((a) {
          final colors = a['colors'] as List<Color>;
          return Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: EdgeInsets.only(
                  right: actions.indexOf(a) < 2 ? 10 : 0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(a['emoji'] as String,
                        style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 6),
                    Text(
                      a['label'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Promo strip ────────────────────────────────────────────────────────────
  Widget _buildPromoStrip() {
    final promos = [
      {'emoji': '🚀', 'title': 'Express Delivery', 'sub': 'In 45 minutes',   'titleColor': const Color(0xFF6C5CE7), 'subColor': const Color(0xFFA090C0)},
      {'emoji': '🆓', 'title': 'Free Delivery',     'sub': 'Orders ₹299+',   'titleColor': AppColors.success, 'subColor': const Color(0xFF80C0A8)},
      {'emoji': '✨', 'title': 'New Arrivals',       'sub': '50+ products',   'titleColor': const Color(0xFFE17055), 'subColor': AppColors.textHint},
    ];

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 8),
        itemCount: promos.length,
        itemBuilder: (_, i) {
          final p = promos[i];
          return Container(
            width: 158,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x25DCA03C), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB47820).withOpacity(0.09),
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

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onAdd;

  const _ProductCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final btnColors = product['btnColors'] as List<Color>;
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0x25DCA03C),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB47820).withOpacity(0.1),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['emoji'] as String,
                    style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text(
                  product['name'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product['brand'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      product['price'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: btnColors),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '+',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: btnColors.last == const Color(0xFFFDCB6E)
                                ? AppColors.textDark
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Badge
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: product['badgeBg'] as Color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  product['badge'] as String,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: product['badgeColor'] as Color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Icon pill with optional badge ─────────────────────────────────────────────

class _IconPill extends StatelessWidget {
  final String emoji;
  final List<Color> gradient;
  final String? badge;

  const _IconPill({required this.emoji, required this.gradient, this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
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
    );
  }
}