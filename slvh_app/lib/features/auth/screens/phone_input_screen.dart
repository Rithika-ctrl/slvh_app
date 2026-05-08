import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../services/auth_service.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Validate phone number (10 digits)
  bool _isValidPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length == 10;
  }

  // Send OTP
  void _sendOTP() async {
    setState(() => _errorMessage = null);

    if (_phoneController.text.isEmpty) {
      setState(() => _errorMessage = 'Phone number cannot be empty');
      return;
    }

    if (!_isValidPhone(_phoneController.text)) {
      setState(() => _errorMessage = AppStrings.phoneError);
      return;
    }

    setState(() => _isLoading = true);

    final phoneNumber = '+91${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';

    await _authService.sendOTP(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId, resendToken) {
        setState(() => _isLoading = false);

        // Navigate to OTP screen using named route
        Navigator.of(context).pushNamed(
          '/otp',
          arguments: {
            'phoneNumber': _phoneController.text,
            'verificationId': verificationId,
          },
        );
      },
      onError: (errorMessage) {
        setState(() {
          _isLoading = false;
          _errorMessage = errorMessage;
        });

        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage ?? 'An error occurred')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / Title
            const Text(
              'SLVH',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppColors.cyan,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'SMART SHOP',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              AppStrings.tagline,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textHint,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Glass Card with Form
            GlassCard(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppStrings.enterPhone,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Phone Input
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    maxLength: 13,
                    enabled: !_isLoading,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '+91 ',
                      hintText: '98765 43210',
                      counterText: '', // Hide character counter
                    ),
                    onSubmitted: (_) => _sendOTP(),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  // Send OTP Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOTP,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : const Text(AppStrings.sendOtp),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Footer
            const Text(
              "We'll send you a 6-digit OTP to verify",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
