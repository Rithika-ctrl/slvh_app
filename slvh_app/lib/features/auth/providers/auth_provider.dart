import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slvh_app/features/auth/services/auth_service.dart';
import 'package:slvh_app/features/auth/services/otp_resend_service.dart';

/// Auth service provider
final authServiceProvider = Provider((ref) => AuthService());

/// OTP resend service provider
final otpResendServiceProvider = Provider((ref) => OTPResendService());

/// Get remaining wait time before next OTP resend (in seconds)
final otpResendWaitTimeProvider =
    FutureProvider.family<int, String>((ref, phoneNumber) async {
  final otpService = ref.read(otpResendServiceProvider);
  return otpService.getResendWaitTime(phoneNumber);
});

/// Get current OTP resend attempt count
final otpResendCountProvider =
    FutureProvider.family<int, String>((ref, phoneNumber) async {
  final otpService = ref.read(otpResendServiceProvider);
  return otpService.getResendCount(phoneNumber);
});

/// Check if user can resend OTP (wait time == 0)
final canResendOTPProvider =
    FutureProvider.family<bool, String>((ref, phoneNumber) async {
  final waitTime = await ref.watch(otpResendWaitTimeProvider(phoneNumber).future);
  return waitTime <= 0;
});
