import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../connectivity/connectivity_provider.dart';
import '../../core/constants/app_colors.dart';

/// NoInternetOverlay
///
/// Feature 11: Offline / No Internet Handling
///
/// Wraps any screen's body with an animated banner that slides down
/// from the top when the device goes offline and slides away when
/// connectivity is restored.
///
/// Usage — wrap your Scaffold body:
///
/// ```dart
/// Scaffold(
///   body: NoInternetOverlay(
///     child: YourActualContent(),
///   ),
/// )
/// ```
///
/// The child remains fully interactive — the banner is a non-blocking
/// top strip, NOT a full-screen modal, so users can still browse cached
/// content, manage their cart, and read past orders while offline.
class NoInternetOverlay extends StatefulWidget {
  final Widget child;

  const NoInternetOverlay({super.key, required this.child});

  @override
  State<NoInternetOverlay> createState() => _NoInternetOverlayState();
}

class _NoInternetOverlayState extends State<NoInternetOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleOnlineChange(bool isOnline) {
    if (!isOnline) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        // Drive animation on state change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleOnlineChange(connectivity.isOnline);
        });

        return Stack(
          children: [
            // ── Main content — always present ───────────────────────────
            widget.child,

            // ── Offline banner — slides in from the top ─────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: _OfflineBanner(
                    isOnline: connectivity.isOnline,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Banner widget ─────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final bool isOnline;
  const _OfflineBanner({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    // Show "back online" in green briefly, then the banner slides out.
    final Color bg =
        isOnline ? AppColors.success : const Color(0xFF2D1B00).withOpacity(0.93);
    final String label =
        isOnline ? '✓  Back online' : 'No internet connection';
    final IconData icon =
        isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (!isOnline)
                  const Text(
                    'Some features unavailable',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
