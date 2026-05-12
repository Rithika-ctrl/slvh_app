import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Exception for OTP resend failures
class OTPResendException implements Exception {
  final String message;
  final String? code; // 'rate_limited', 'max_resends_exceeded', etc.
  final int? retryAfterSeconds; // Time to wait before next resend

  OTPResendException({
    required this.message,
    this.code,
    this.retryAfterSeconds,
  });

  @override
  String toString() => message;
}

/// Service for OTP resend with throttling and rate limiting
/// 
/// Prevents abuse by:
/// 1. Tracking last resend timestamp
/// 2. Enforcing 30-second minimum between resends
/// 3. Limiting total resends to 3 per OTP session
/// 4. Blocking rapid resend attempts
class OTPResendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Configuration
  static const int resendMinimumIntervalSeconds = 30;
  static const int maxResendAttempts = 3;

  /// Request OTP resend with throttling
  /// 
  /// Validates:
  /// 1. At least 30 seconds since last resend
  /// 2. Total resends <= 3 per OTP session
  /// 3. User exists in Firestore
  /// 
  /// Returns: true if resend was allowed
  /// Throws: OTPResendException if rate-limited or max resends exceeded
  Future<bool> requestResend({
    required String phoneNumber,
    required Function(String errorMessage) onError,
  }) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      final userDoc = _firestore.collection('users').doc(normalizedPhone);

      // Get or create user document
      final userSnapshot = await userDoc.get();

      DateTime now = DateTime.now();
      Map<String, dynamic> userData = userSnapshot.data() ?? {};

      // STEP 1: Check if resend is rate-limited
      final lastResendAt = userData['resend_at'] as Timestamp?;
      if (lastResendAt != null) {
        final secondsSinceLastResend =
            now.difference(lastResendAt.toDate()).inSeconds;

        if (secondsSinceLastResend < resendMinimumIntervalSeconds) {
          final retryAfter = resendMinimumIntervalSeconds - secondsSinceLastResend;
          final message =
              'Please wait ${retryAfter}s before requesting another OTP';

          print('❌ OTP resend rate-limited: $message');

          throw OTPResendException(
            message: message,
            code: 'rate_limited',
            retryAfterSeconds: retryAfter,
          );
        }
      }

      // STEP 2: Check total resend count
      final resendCount = userData['resend_count'] as int? ?? 0;
      if (resendCount >= maxResendAttempts) {
        final message =
            'Maximum OTP resend attempts (3) exceeded. Please try again later.';

        print('❌ OTP max resends exceeded: $message');

        throw OTPResendException(
          message: message,
          code: 'max_resends_exceeded',
          retryAfterSeconds: 3600, // 1 hour
        );
      }

      // STEP 3: Allow resend - update throttling fields in Firestore
      await userDoc.set({
        'phone': normalizedPhone,
        'resend_at': now,
        'resend_count': resendCount + 1,
        'resend_at_formatted': now.toIso8601String(),
        'updated_at': now,
      }, SetOptions(merge: true));

      print(
          '✅ OTP resend allowed for $normalizedPhone (attempt ${resendCount + 1}/$maxResendAttempts)');
      return true;
    } catch (e) {
      if (e is OTPResendException) {
        onError(e.message);
        rethrow;
      }

      final message = 'Failed to process resend request: ${e.toString()}';
      print('❌ OTP resend error: $message');

      onError(message);
      throw OTPResendException(message: message, code: 'unknown_error');
    }
  }

  /// Reset resend counter after successful OTP verification
  /// Call this after customer successfully verifies the OTP
  Future<void> resetResendCounter(String phoneNumber) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      await _firestore.collection('users').doc(normalizedPhone).set({
        'resend_count': 0,
        'resend_at': null,
        'otp_verified_at': DateTime.now(),
      }, SetOptions(merge: true));

      print('✅ Resend counter reset for $normalizedPhone');
    } catch (e) {
      print('⚠️ Failed to reset resend counter: $e');
      // Don't throw - not critical if reset fails
    }
  }

  /// Get remaining time before next resend is allowed
  /// Returns: seconds until next resend allowed, or 0 if can resend now
  Future<int> getResendWaitTime(String phoneNumber) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      final userDoc = await _firestore
          .collection('users')
          .doc(normalizedPhone)
          .get();

      if (!userDoc.exists) {
        return 0; // Can resend immediately
      }

      final lastResendAt = userDoc['resend_at'] as Timestamp?;
      if (lastResendAt == null) {
        return 0; // Never resent, can resend now
      }

      final secondsSinceLastResend =
          DateTime.now().difference(lastResendAt.toDate()).inSeconds;
      final waitTime = resendMinimumIntervalSeconds - secondsSinceLastResend;

      return waitTime > 0 ? waitTime : 0;
    } catch (e) {
      print('⚠️ Failed to get resend wait time: $e');
      return 0; // If error, assume can resend
    }
  }

  /// Get current resend attempt count
  Future<int> getResendCount(String phoneNumber) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      final userDoc = await _firestore
          .collection('users')
          .doc(normalizedPhone)
          .get();

      if (!userDoc.exists) {
        return 0;
      }

      return userDoc['resend_count'] as int? ?? 0;
    } catch (e) {
      print('⚠️ Failed to get resend count: $e');
      return 0;
    }
  }

  /// Clear all OTP-related data (on logout or session end)
  Future<void> clearOTPSession(String phoneNumber) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      await _firestore.collection('users').doc(normalizedPhone).set({
        'resend_count': 0,
        'resend_at': null,
        'otp_verified_at': null,
        'cleared_at': DateTime.now(),
      }, SetOptions(merge: true));

      print('✅ OTP session cleared for $normalizedPhone');
    } catch (e) {
      print('⚠️ Failed to clear OTP session: $e');
    }
  }

  /// Normalize phone number to +91XXXXXXXXXX format
  String _normalizePhoneNumber(String phone) {
    if (phone.startsWith('+')) {
      return phone;
    }
    return '+91${phone.replaceAll(RegExp(r'\D'), '')}';
  }
}
