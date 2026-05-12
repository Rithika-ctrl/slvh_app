import 'package:flutter/material.dart';
import 'package:slvh_app/core/constants/app_colors.dart';

/// OTP expiry and resend countdown timer widget
/// 
/// Shows:
/// - Time remaining for OTP (0-60 seconds)
/// - "Resend OTP" button appears after 30 seconds
/// - Color changes: Green → Orange → Red as time runs out
/// - Callback when timer expires (60s)
/// - Callback when resend becomes available (30s)
class OTPCountdownTimer extends StatefulWidget {
  /// Total OTP expiry time in seconds (default 60s)
  final int totalSeconds;

  /// Time after which resend button becomes available (default 30s)
  final int resendAvailableAfter;

  /// Callback when timer expires
  final VoidCallback onExpired;

  /// Callback when resend becomes available (optional)
  final VoidCallback? onResendAvailable;

  /// Callback when resend is tapped
  final VoidCallback onResendTapped;

  /// Whether resend is currently being processed (for loading state)
  final bool isResending;

  const OTPCountdownTimer({
    Key? key,
    this.totalSeconds = 60,
    this.resendAvailableAfter = 30,
    required this.onExpired,
    this.onResendAvailable,
    required this.onResendTapped,
    this.isResending = false,
  }) : super(key: key);

  @override
  State<OTPCountdownTimer> createState() => _OTPCountdownTimerState();
}

class _OTPCountdownTimerState extends State<OTPCountdownTimer> {
  late int _timeRemaining;
  bool _resendAvailable = false;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _timeRemaining = widget.totalSeconds;
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _timeRemaining--;

        // Check if resend just became available
        if (_timeRemaining == widget.resendAvailableAfter &&
            !_resendAvailable) {
          _resendAvailable = true;
          widget.onResendAvailable?.call();
        }

        // Check if OTP expired
        if (_timeRemaining <= 0) {
          _expired = true;
          widget.onExpired();
          return; // Stop timer
        }
      });

      if (!_expired) {
        _startTimer(); // Continue timer
      }
    });
  }

  /// Get color based on time remaining
  Color _getTimeColor() {
    if (_expired) return AppColors.danger; // Red
    if (_timeRemaining <= 10) return AppColors.danger; // Red (< 10s)
    if (_timeRemaining <= 20) return AppColors.orange; // Orange (< 20s)
    return AppColors.success; // Green
  }

  /// Get icon based on time remaining
  IconData _getTimeIcon() {
    if (_expired) return Icons.error_outline;
    if (_timeRemaining <= 10) return Icons.warning_amber;
    return Icons.access_time;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Timer display with icon ──────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getTimeColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getTimeColor().withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getTimeIcon(),
                color: _getTimeColor(),
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _expired ? 'OTP Expired' : 'OTP expires in',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _expired
                        ? 'Please request a new OTP'
                        : '${_timeRemaining}s',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getTimeColor(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Resend button (appears after 30 seconds) ──────────
        if (_resendAvailable && !_expired)
          ElevatedButton.icon(
            onPressed: widget.isResending ? null : widget.onResendTapped,
            icon: widget.isResending
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            label: Text(widget.isResending ? 'Resending...' : 'Resend OTP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
        else if (_expired)
          ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.error_outline),
            label: const Text('OTP Expired'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger.withOpacity(0.3),
              foregroundColor: AppColors.danger,
              disabledBackgroundColor:
                  AppColors.danger.withOpacity(0.3),
              disabledForegroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_clock,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Resend available in ${widget.resendAvailableAfter - _timeRemaining}s',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Widget showing OTP resend status with rate limiting info
class OTPResendStatus extends StatelessWidget {
  final int currentAttempt; // Current resend attempt (1-3)
  final int maxAttempts; // Maximum resend attempts (3)
  final int? waitSeconds; // Seconds to wait before next resend, or null if can resend

  const OTPResendStatus({
    Key? key,
    required this.currentAttempt,
    required this.maxAttempts,
    this.waitSeconds,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final canResend = waitSeconds == null || waitSeconds! <= 0;
    final isExhausted = currentAttempt >= maxAttempts;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExhausted
            ? AppColors.danger.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExhausted
              ? AppColors.danger.withOpacity(0.3)
              : AppColors.warning.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isExhausted ? Icons.error_outline : Icons.info_outline,
            color: isExhausted ? AppColors.danger : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExhausted
                      ? 'No more resend attempts'
                      : 'Resend attempt $currentAttempt of $maxAttempts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isExhausted
                        ? AppColors.danger
                        : AppColors.warning,
                  ),
                ),
                if (!canResend && waitSeconds != null)
                  Text(
                    'Wait ${waitSeconds}s before next resend',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
