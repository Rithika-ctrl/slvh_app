import 'package:flutter/material.dart';
import '../../features/settings/models/shop_settings_model.dart';
import '../../features/settings/services/settings_service.dart';
import '../../core/constants/app_colors.dart';

/// ShopStatusBanner
///
/// Shows a thin banner when the shop is closed, on holiday, or orders
/// are paused. Returns [SizedBox.shrink] when everything is normal.
class ShopStatusBanner extends StatelessWidget {
  const ShopStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ShopSettingsModel>(
      stream: SettingsService.instance.watchSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings == null) return const SizedBox.shrink();

        final now = TimeOfDay.now();
        final isWithinHours =
            now.hour >= settings.openTime && now.hour < settings.closeTime;

        final bool closed = settings.holidayMode ||
            settings.orderPause ||
            !isWithinHours;

        if (!closed) return const SizedBox.shrink();

        String message;
        IconData icon;
        Color bg;

        if (settings.holidayMode) {
          message = '🎉 Shop is on holiday — back soon!';
          icon = Icons.beach_access_rounded;
          bg = AppColors.catPurple;
        } else if (settings.orderPause) {
          message = '⏸ Orders paused temporarily';
          icon = Icons.pause_circle_outline_rounded;
          bg = AppColors.warning.withOpacity(1);
        } else {
          final open = _fmt(settings.openTime);
          final close = _fmt(settings.closeTime);
          message = '🕐 Shop opens $open – $close';
          icon = Icons.access_time_rounded;
          bg = AppColors.textMid;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:00 $period';
  }
}