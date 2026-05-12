import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:slvh_app/features/auth/services/otp_resend_service.dart';
import 'package:slvh_app/features/auth/widgets/otp_countdown_timer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../services/auth_service.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  final AuthService _authService = AuthService();
  final OTPResendService _otpResendService = OTPResendService();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendAttempts = 0;
  bool _otpExpired = false;
  int? _currentResendToken;

  // Shake animation
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _currentResendToken = widget.resendToken;
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);
    _loadResendAttempts();
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  /// Load previous resend attempts from Firestore
  Future<void> _loadResendAttempts() async {
    try {
      final count = await _otpResendService.getResendCount(widget.phoneNumber);
      setState(() => _resendAttempts = count);
    } catch (e) {
      print('⚠️ Failed to load resend attempts: $e');
    }
  }

  /// Check if phone number is a Firebase test number
  bool _isTestPhoneNumber(String phoneNumber) {
    final testNumbers = [
      '9999999999',
      '9876543210',
      '9111111111',
      '1234567890',
    ];
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    return testNumbers.contains(digitsOnly);
  }

  void _onDigitEntered(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  String get _fullOTP =>
      _controllers.map((c) => c.text).join();

  void _shake() {
    _shakeCtrl.forward(from: 0);
  }

  /// Verify OTP and proceed to home
  void _verifyOTP() async {
    if (_fullOTP.length != 6) {
      _shake();
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    if (_otpExpired) {
      setState(() => _errorMessage = 'OTP expired. Please request a new one.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = await _authService.verifyOTP(
      otp: _fullOTP,
      phoneNumber: widget.phoneNumber,
      verificationId: widget.verificationId,
      onError: (msg) {
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
        _shake();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.danger,
          ),
        );
      },
    );

    if (isValid && mounted) {
      setState(() => _isLoading = false);
      // Clear OTP session on successful verification
      await _otpResendService.clearOTPSession(widget.phoneNumber);
      context.go('/home');
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Resend OTP with throttling and rate limiting
  void _resendOTP() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await _authService.resendOTP(
        phoneNumber: widget.phoneNumber,
        resendToken: _currentResendToken,
        onCodeSent: (verificationId, resendToken) {
          setState(() {
            _isResending = false;
            _currentResendToken = resendToken;
            _resendAttempts++;
          });

          // Clear OTP input
          for (var c in _controllers) c.clear();
          _focusNodes[0].requestFocus();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'OTP resent! Check your SMS. Wait 30s before next resend.'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        },
        onError: (msg) {
          setState(() {
            _isResending = false;
            _errorMessage = msg;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      );
    } on OTPResendException catch (e) {
      setState(() {
        _isResending = false;
        _errorMessage = e.message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ─────────────────────────────────────
            Row(
              children: [
                _BackButton(onTap: () => Navigator.pop(context)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.24),
                      width: 1.5,
                    ),
                  ),
                  child: const Text(
                    '✓ Secure Channel',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Header ──────────────────────────────────────
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
                      child: Text('📲', style: TextStyle(fontSize: 38)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Verify OTP',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.orange,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                      children: [
                        const TextSpan(text: 'Code sent to '),
                        TextSpan(
                          text: '+91 ${widget.phoneNumber}',
                          style: const TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── OTP Countdown Timer ──────────────────────────
            OTPCountdownTimer(
              totalSeconds: 60,
              resendAvailableAfter: 30,
              onExpired: () {
                setState(() => _otpExpired = true);
              },
              onResendAvailable: () {
                // Timer shows resend is available
              },
              onResendTapped: _resendOTP,
              isResending: _isResending,
            ),

            const SizedBox(height: 24),

            // ── OTP boxes ────────────────────────────────────
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) {
                final offset = _shakeCtrl.isAnimating
                    ? ((_shakeAnim.value * 4).floor().isEven ? -9.0 : 9.0) *
                        (1 - _shakeAnim.value)
                    : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => _OTPBox(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  isFirst: i == 0,
                  isLoading: _isLoading,
                  onChanged: (v) => _onDigitEntered(v, i),
                  onBackspace: () {
                    if (_controllers[i].text.isEmpty && i > 0) {
                      _focusNodes[i - 1].requestFocus();
                      _controllers[i - 1].clear();
                      setState(() {});
                    }
                  },
                )),
              ),
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Text(
                    '💡 Development Mode: Enter any 6-digit code',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ── Verify button ────────────────────────────────
            _OrangeButton(
              label: '✓ Verify & Continue',
              isLoading: _isLoading,
              onTap: _verifyOTP,
            ),

            const SizedBox(height: 20),

            // ── Resend attempt counter ───────────────────────
            OTPResendStatus(
              currentAttempt: _resendAttempts,
              maxAttempts: 3,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── OTP single box ────────────────────────────────────────────────────────────

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
              ? AppColors.orange.withOpacity(0.1)
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

// ── Orange Button ────────────────────────────────────────────────────────────

class _OrangeButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _OrangeButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFA500),
              Color(0xFFFF8C00),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'Nunito',
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Back button ──────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.36),
            width: 1.5,
          ),
        ),
        child: const Center(
          child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
