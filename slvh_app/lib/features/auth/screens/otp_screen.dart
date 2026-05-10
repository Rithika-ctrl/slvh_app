import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../services/auth_service.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
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
  bool _isLoading = false;
  String? _errorMessage;
  int _resendCountdown = 60;
  bool _canResend = false;

  // Shake animation
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _canResend = false;
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          _canResend = true;
        } else {
          _tick();
        }
      });
    });
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

  void _verifyOTP() async {
    if (_fullOTP.length != 6) {
      _shake();
      setState(() => _errorMessage = 'Please enter all 6 digits');
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
          SnackBar(content: Text(msg)),
        );
      },
    );

    if (isValid) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.go('/home');
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _resendOTP() {
    if (!_canResend) return;
    for (var c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
    setState(() => _errorMessage = null);
    _startResendTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP resent! Check your SMS.')),
    );
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
              ),

            const SizedBox(height: 24),

            // ── Verify button ────────────────────────────────
            _OrangeButton(
              label: '✓ Verify & Continue',
              isLoading: _isLoading,
              onTap: _verifyOTP,
            ),

            const SizedBox(height: 14),

            // ── Resend ───────────────────────────────────────
            Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                  children: [
                    const TextSpan(text: "Didn't receive it? "),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: _canResend ? _resendOTP : null,
                        child: Text(
                          _canResend
                              ? '↩ Resend OTP'
                              : 'Resend in ${_resendCountdown}s',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _canResend
                                ? AppColors.orange
                                : AppColors.textHint,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        child: RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: (event) {
            if (event is RawKeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.backspace &&
                controller.text.isEmpty) {
              onBackspace();
            }
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: !isLoading,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            autofocus: isFirst,
          ),
        ),
      ),
    );
  }
}

// ── Orange button ─────────────────────────────────────────────────────────────

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
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9F43), AppColors.orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withOpacity(0.42),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            : Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0x38DCA03C),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB47820).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textMuted,
          size: 18,
        ),
      ),
    );
  }
}