import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../services/auth_service.dart';
import '../../../core/utils/secure_logger.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _badgeAnim;
  late Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    _badgeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _badgeScale = CurvedAnimation(
      parent: _badgeAnim,
      curve: const ElasticOutCurve(0.9),
    );
    _badgeAnim.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _badgeAnim.dispose();
    super.dispose();
  }

  bool _isValidPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length == 10;
  }

  void _sendOTP() async {
    setState(() => _errorMessage = null);
    FocusScope.of(context).unfocus();

    if (_phoneController.text.isEmpty) {
      setState(() => _errorMessage = 'Phone number cannot be empty');
      return;
    }
    if (!_isValidPhone(_phoneController.text)) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit number');
      return;
    }

    setState(() => _isLoading = true);

    // Extract just the phone number (without country code for fake OTP)
    final phoneNumber = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    await _authService.sendOTP(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId, resendToken) {
        setState(() => _isLoading = false);
        context.go(
          '/otp',
          extra: {
            'phoneNumber': phoneNumber,
            'verificationId': verificationId,
          },
        );
      },
      onError: (errorMessage) {
        setState(() {
          _isLoading = false;
          // Provide helpful error messages
          if (kIsWeb && errorMessage.contains('recaptcha')) {
            _errorMessage = 'Please check your internet connection and try again';
          } else {
            _errorMessage = errorMessage;
          }
        });
        AppLogger.debug('❌ OTP Error: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? 'An error occurred'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 50),
        child: Column(
          children: [
            // ── Brand badge ──────────────────────────────────
            ScaleTransition(
              scale: _badgeScale,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB347), AppColors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withOpacity(0.44),
                      blurRadius: 34,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.65),
                      blurRadius: 0,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🛒', style: TextStyle(fontSize: 44)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Brand name ───────────────────────────────────
            const Text(
              'SLVH',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: AppColors.orange,
                letterSpacing: 7,
                fontFamily: 'Nunito',
              ),
            ),
            const Text(
              'SMART SHOP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 14),

            // ── Pill strip ───────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: const [
                _Pill('🧴 Care'),
                _Pill('🧼 Hygiene'),
                _Pill('🧹 Clean'),
                _Pill('📦 Staples'),
              ],
            ),

            const SizedBox(height: 30),

            // ── Login card ───────────────────────────────────
            GlassCard(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label row
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB347), AppColors.orange],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('📱', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Enter your mobile number',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Phone input
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF8EE), Color(0xFFFFF2E0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.orange.withOpacity(0.32),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange.withOpacity(0.08),
                          blurRadius: 0,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '+91 ',
                          style: TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            maxLength: 10,
                            enabled: !_isLoading,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                            decoration: const InputDecoration(
                              hintText: '98765 43210',
                              hintStyle: TextStyle(
                                color: AppColors.textHint,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                              counterText: '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              filled: false,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onSubmitted: (_) => _sendOTP(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Send OTP button
                  _OrangeButton(
                    label: 'Send OTP',
                    icon: '→',
                    isLoading: _isLoading,
                    onTap: _sendOTP,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Footer text
            const Text(
              '🔒 6-digit OTP will be sent to verify',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 8),

            // Development mode notice
            Text(
              '💡 Development Mode: Enter any 10-digit number',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.orange.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 10),

            // Admin access
            GestureDetector(
              onTap: () => context.go('/admin-login'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.orange.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: const Text(
                  'Admin Access',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.orange.withOpacity(0.11),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.orange.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _OrangeButton extends StatelessWidget {
  final String label;
  final String icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _OrangeButton({
    required this.label,
    required this.icon,
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        icon,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
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

