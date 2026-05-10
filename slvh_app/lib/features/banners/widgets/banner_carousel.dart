/// BannerCarousel
///
/// Shows active promotional banners fetched from Firestore in an
/// auto-advancing carousel.  Tapping a banner navigates to its deeplink
/// using GoRouter if one is set.
///
/// Drop-in replacement for the hard-coded offer banner in HomeScreen.
///
/// Usage:
/// ```dart
/// SliverToBoxAdapter(child: BannerCarousel()),
/// ```

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../services/banner_service.dart';
import '../models/banner_model.dart';

class BannerCarousel extends StatefulWidget {
  /// Duration each slide is shown before auto-advancing.
  final Duration autoPlayInterval;

  const BannerCarousel({
    super.key,
    this.autoPlayInterval = const Duration(seconds: 4),
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final BannerService _service = BannerService();
  final PageController _pageCtrl = PageController();

  List<BannerModel> _banners = [];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startAutoPlay(int count) {
    if (count <= 1) return;
    Future.delayed(widget.autoPlayInterval, () {
      if (!mounted) return;
      final next = (_currentPage + 1) % count;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _startAutoPlay(count);
    });
  }

  void _onBannerTap(BannerModel banner) {
    if (banner.deeplink?.isNotEmpty == true) {
      context.push(banner.deeplink!);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BannerModel>>(
      stream: _service.watchActiveBanners(),
      builder: (context, snapshot) {
        final banners = snapshot.data ?? [];

        // Kick off auto-play when banner list changes
        if (banners.isNotEmpty && banners != _banners) {
          _banners = banners;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startAutoPlay(banners.length);
          });
        }

        // Loading skeleton
        if (snapshot.connectionState == ConnectionState.waiting &&
            banners.isEmpty) {
          return _Skeleton();
        }

        // No active banners – show nothing (parent can insert a fallback)
        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
          child: Column(
            children: [
              // ── Carousel ─────────────────────────────────────────────────
              SizedBox(
                height: 160,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: banners.length,
                  onPageChanged: (i) =>
                      setState(() => _currentPage = i),
                  itemBuilder: (_, index) {
                    final b = banners[index];
                    return _BannerSlide(
                      banner: b,
                      onTap: () => _onBannerTap(b),
                    );
                  },
                ),
              ),

              // ── Dots indicator ────────────────────────────────────────────
              if (banners.length > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    banners.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentPage ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? AppColors.orange
                            : AppColors.orange.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual slide
// ─────────────────────────────────────────────────────────────────────────────

class _BannerSlide extends StatelessWidget {
  final BannerModel banner;
  final VoidCallback onTap;

  const _BannerSlide({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB47820).withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: CachedNetworkImage(
            imageUrl: banner.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 160,
            placeholder: (_, __) => Container(
              color: AppColors.bgCreamLight,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.orange),
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.bgCreamLight,
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_rounded,
                  size: 40,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _Skeleton extends StatefulWidget {
  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppColors.bgCreamLight.withOpacity(_anim.value),
          ),
        ),
      ),
    );
  }
}