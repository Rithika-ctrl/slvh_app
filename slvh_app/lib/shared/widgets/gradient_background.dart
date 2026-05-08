import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      body: Stack(
        children: [
          // Cream base
          Container(color: AppColors.bgCream),

          // Warm blob 1 — top-left
          Positioned(
            top: -130,
            left: -110,
            child: _blob(340, const Color(0xFFFFB43C), 0.13),
          ),

          // Warm blob 2 — bottom-right
          Positioned(
            bottom: -90,
            right: -80,
            child: _blob(280, const Color(0xFFFF6432), 0.08),
          ),

          // Warm blob 3 — mid-left
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: -60,
            child: _blob(190, const Color(0xFFFFDC5A), 0.11),
          ),

          // Warm blob 4 — mid-right
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            right: -35,
            child: _blob(130, const Color(0xFFFF8C3C), 0.09),
          ),

          // Dotted overlay
          Positioned.fill(
            child: CustomPaint(painter: _DotPatternPainter()),
          ),

          // Safe area content
          SafeArea(child: child),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCAA28).withOpacity(0.07)
      ..style = PaintingStyle.fill;

    const double spacing = 26;
    const double radius = 1.5;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) => false;
}