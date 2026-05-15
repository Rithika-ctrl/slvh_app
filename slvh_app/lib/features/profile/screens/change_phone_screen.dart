import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/widgets/otp_countdown_timer.dart';
import '../services/user_profile_service.dart';

/// Two-step phone-change flow:
///
///   Step 1 — Enter new phone number → send OTP
///   Step 2 — Enter 6-digit OTP → verify → migrate Firestore doc →
///             update SharedPreferences → pop back to profile
///
/// The old phone number is passed in so the Firestore migration can copy
/// existing data across (name, role, orders…) before deleting the old doc.
class ChangePhoneScreen extends StatefulWidget {
  /// The currently registered phone number (used as Firestore doc key).
  final String currentPhone;

  const ChangePhoneScreen({super.key, required this.currentPhone});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen>
    with SingleTickerProviderStateMixin {
  // ── Step tracking ───────────────────────────────────────────────────────
  bool _onOTPStep = false;

  // ── Step 1 ─────────────────────────────────────────────────────────────
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _sendingOTP = false;
  String? _step1Error;

  // ── Step 2 ─────────────────────────────────────────────────────────────
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  String _verificationId = '';
  int? _resendToken;
  bool _verifying = false;
  bool _resending = false;
  bool _otpExpired = false;
  String? _step2Error;

  // ── Shake animation ─────────────────────────────────────────────────────
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  final AuthService _authService = AuthService();
  final UserProfileService _profileService = UserProfileService();

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  bool _isValidPhone(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '').length == 10;

  String get _newPhone =>
      '+91${_phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '')}';

  String get _fullOTP => _otpCtrls.map((c) => c.text).join();

  void _shake() => _shakeCtrl.forward(from: 0);

  // ── Step 1 — Send OTP ──────────────────────────────────────────────────

  Future<void> _sendOTP() async {
    setState(() {
      _step1Error = null;
      _sendingOTP = true;
    });
    FocusScope.of(context).unfocus();

    final raw = _phoneCtrl.text.trim();

    if (!_isValidPhone(raw)) {
      setState(() {
        _step1Error = 'Enter a valid 10-digit mobile number.';
        _sendingOTP = false;
      });
      return;
    }

    // Prevent switching to the same number.
    if (_newPhone == widget.currentPhone) {
      setState(() {
        _step1Error = 'New number must be different from the current one.';
        _sendingOTP = false;
      });
      return;
    }

    await _authService.sendOTP(
      phoneNumber: raw,
      onCodeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _sendingOTP = false;
          _onOTPStep = true;
        });
      },
      onError: (msg) {
        setState(() {
          _step1Error = msg;
          _sendingOTP = false;
        });
      },
    );
  }

  // ── Step 2 — Verify OTP & migrate ─────────────────────────────────────

  Future<void> _verifyAndSave() async {
    if (_fullOTP.length != 6) {
      _shake();
      setState(() => _step2Error = 'Enter all 6 digits.');
      return;
    }
    if (_otpExpired) {
      setState(() => _step2Error = 'OTP expired — request a new one.');
      return;
    }

    setState(() {
      _verifying = true;
      _step2Error = null;
    });

    final ok = await _authService.verifyOTP(
      otp: _fullOTP,
      phoneNumber: _phoneCtrl.text.trim(),
      verificationId: _verificationId,
      onError: (msg) {
        setState(() {
          _verifying = false;
          _step2Error = msg;
        });
        _shake();
      },
    );

    if (!ok || !mounted) return;

    // ── Migrate Firestore doc & update local session ──────────────────────
    try {
      await _profileService.migratePhone(
        oldPhone: widget.currentPhone,
        newPhone: _newPhone,
      );

      // Update cached phone in SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone_number', _newPhone);
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _step2Error = 'Failed to save new number. Please try again.';
        });
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone updated to $_newPhone'),
          backgroundColor: AppColors.success,
        ),
      );
      // Return the new phone so ProfileScreen can refresh.
      Navigator.of(context).pop(_newPhone);
    }
  }

  // ── Step 2 — Resend OTP ────────────────────────────────────────────────

  Future<void> _resendOTP() async {
    setState(() {
      _resending = true;
      _step2Error = null;
    });

    await _authService.resendOTP(
      phoneNumber: _phoneCtrl.text.trim(),
      resendToken: _resendToken,
      onCodeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _resending = false;
          _otpExpired = false;
        });
        for (final c in _otpCtrls) c.clear();
        _otpFocus[0].requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP resent!'),
            backgroundColor: AppColors.success,
          ),
        );
      },
      onError: (msg) {
        setState(() {
          _resending = false;
          _step2Error = msg;
        });
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () {
              if (_onOTPStep) {
                setState(() => _onOTPStep = false);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            _onOTPStep ? 'Verify New Number' : 'Change Phone',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 12,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position:
                      Tween(begin: const Offset(0.06, 0), end: Offset.zero)
                          .animate(anim),
                  child: child,
                ),
              ),
              child: _onOTPStep
                  ? _OTPStep(
                      key: const ValueKey('otp'),
                      newPhone: _newPhone,
                      controllers: _otpCtrls,
                      focusNodes: _otpFocus,
                      shakeAnim: _shakeAnim,
                      shakeCtrl: _shakeCtrl,
                      isVerifying: _verifying,
                      isResending: _resending,
                      otpExpired: _otpExpired,
                      errorMessage: _step2Error,
                      onVerify: _verifyAndSave,
                      onResend: _resendOTP,
                      onExpired: () => setState(() => _otpExpired = true),
                    )
                  : _PhoneStep(
                      key: const ValueKey('phone'),
                      controller: _phoneCtrl,
                      currentPhone: widget.currentPhone,
                      isSending: _sendingOTP,
                      errorMessage: _step1Error,
                      onSend: _sendOTP,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step 1 widget — enter new phone ──────────────────────────────────────────

class _PhoneStep extends StatelessWidget {
  final TextEditingController controller;
  final String currentPhone;
  final bool isSending;
  final String? errorMessage;
  final VoidCallback onSend;

  const _PhoneStep({
    super.key,
    required this.controller,
    required this.currentPhone,
    required this.isSending,
    required this.errorMessage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // ── Icon + title ──────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF8EE), Color(0xFFFFE0BB)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withOpacity(0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('📱', style: TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'New Phone Number',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Current: $currentPhone',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ── Input card ────────────────────────────────────────────────────
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Country prefix badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.orange.withOpacity(0.22),
                        ),
                      ),
                      child: const Text(
                        '🇮🇳 +91',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.orange,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          hintText: '10-digit number',
                          hintStyle: const TextStyle(
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        onFieldSubmitted: (_) => onSend(),
                      ),
                    ),
                  ],
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Info note ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.orange.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.orange.withOpacity(0.18)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'An OTP will be sent to verify the new number before it is saved.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMid,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Send OTP button ───────────────────────────────────────────────
        _ActionButton(
          label: 'Send OTP',
          icon: Icons.send_rounded,
          isLoading: isSending,
          onTap: onSend,
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Step 2 widget — OTP verification ─────────────────────────────────────────

class _OTPStep extends StatelessWidget {
  final String newPhone;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final Animation<double> shakeAnim;
  final AnimationController shakeCtrl;
  final bool isVerifying;
  final bool isResending;
  final bool otpExpired;
  final String? errorMessage;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onExpired;

  const _OTPStep({
    super.key,
    required this.newPhone,
    required this.controllers,
    required this.focusNodes,
    required this.shakeAnim,
    required this.shakeCtrl,
    required this.isVerifying,
    required this.isResending,
    required this.otpExpired,
    required this.errorMessage,
    required this.onVerify,
    required this.onResend,
    required this.onExpired,
  });

  void _onDigit(String value, int index) {
    if (value.length == 1 && index < 5) {
      focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),

        // ── Icon + subtitle ───────────────────────────────────────────────
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8EE), Color(0xFFFFE0BB)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withOpacity(0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: Text('📲', style: TextStyle(fontSize: 38)),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Verify New Number',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
            children: [
              const TextSpan(text: 'OTP sent to '),
              TextSpan(
                text: newPhone,
                style: const TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Countdown timer ───────────────────────────────────────────────
        OTPCountdownTimer(
          totalSeconds: 60,
          resendAvailableAfter: 30,
          onExpired: onExpired,
          onResendAvailable: () {},
          onResendTapped: onResend,
          isResending: isResending,
        ),

        const SizedBox(height: 24),

        // ── 6-box OTP input ───────────────────────────────────────────────
        AnimatedBuilder(
          animation: shakeAnim,
          builder: (_, child) {
            final offset = shakeCtrl.isAnimating
                ? ((shakeAnim.value * 4).floor().isEven ? -9.0 : 9.0) *
                    (1 - shakeAnim.value)
                : 0.0;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              6,
              (i) => _OTPBox(
                controller: controllers[i],
                focusNode: focusNodes[i],
                isFirst: i == 0,
                isLoading: isVerifying,
                onChanged: (v) => _onDigit(v, i),
                onBackspace: () {
                  if (controllers[i].text.isEmpty && i > 0) {
                    focusNodes[i - 1].requestFocus();
                    controllers[i - 1].clear();
                  }
                },
              ),
            ),
          ),
        ),

        if (errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            errorMessage!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          const SizedBox(height: 10),
          const Text(
            '💡 Dev mode: enter any 6-digit code',
            style: TextStyle(
              color: AppColors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],

        const SizedBox(height: 24),

        // ── Verify button ─────────────────────────────────────────────────
        _ActionButton(
          label: 'Confirm New Number',
          icon: Icons.check_circle_outline_rounded,
          isLoading: isVerifying,
          onTap: onVerify,
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _OTPBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFirst;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OTPBox({
    required this.controller,
    required this.focusNode,
    required this.isFirst,
    required this.isLoading,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final filled = controller.text.isNotEmpty;
    final focused = focusNode.hasFocus;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 58,
        decoration: BoxDecoration(
          color: filled
              ? AppColors.orange.withOpacity(0.10)
              : Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: focused
                ? AppColors.orange
                : filled
                    ? AppColors.orangeLight
                    : const Color(0x4CDCA03C),
            width: 2.5,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AppColors.orange.withOpacity(0.18),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: !isLoading,
          textAlign: TextAlign.center,
          autofocus: isFirst,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: isLoading
              ? const LinearGradient(
                  colors: [Color(0xFFFFB347), Color(0xFFE07800)])
              : const LinearGradient(
                  colors: [Color(0xFFFFA500), Color(0xFFE07800)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}