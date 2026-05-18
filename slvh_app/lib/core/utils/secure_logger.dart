import 'package:flutter/foundation.dart';

/// Secure logger that respects kDebugMode
/// 
/// CRITICAL SECURITY: All debug logs are completely suppressed in release builds.
/// Sensitive data (phone numbers, tokens, order IDs, user data) is never exposed
/// to logcat or system logs in production.
/// 
/// Usage:
/// ```dart
/// import 'package:slvh_app/core/utils/secure_logger.dart';
/// 
/// AppLogger.debug('User phone: $phoneNumber');  // Only shown in debug builds
/// AppLogger.info('✅ Order created');            // Only shown in debug builds
/// AppLogger.warning('⚠️ Low stock detected');    // Only shown in debug builds
/// AppLogger.error('❌ Payment failed', error);   // Only shown in debug builds
/// ```
/// 
/// Release Build Behavior: All logs are completely suppressed (zero overhead)
/// Debug Build Behavior: All logs printed to console with appropriate tags
class AppLogger {
  AppLogger._();

  /// Log debug message (only in debug mode)
  static void debug(String message) {
    if (kDebugMode) {
      print('🔍 DEBUG: $message');
    }
  }

  /// Log info message (only in debug mode)
  static void info(String message) {
    if (kDebugMode) {
      print('ℹ️ INFO: $message');
    }
  }

  /// Log warning message (only in debug mode)
  static void warning(String message) {
    if (kDebugMode) {
      print('⚠️ WARNING: $message');
    }
  }

  /// Log error message with optional exception (only in debug mode)
  static void error(String message, [dynamic exception, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('❌ ERROR: $message');
      if (exception != null) {
        print('   Exception: $exception');
      }
      if (stackTrace != null) {
        print('   StackTrace: $stackTrace');
      }
    }
  }

  /// Log success message (only in debug mode)
  static void success(String message) {
    if (kDebugMode) {
      print('✅ SUCCESS: $message');
    }
  }

  /// Log critical/alert message (only in debug mode)
  static void critical(String message) {
    if (kDebugMode) {
      print('🚨 CRITICAL: $message');
    }
  }

  /// Log with custom emoji/prefix (only in debug mode)
  static void custom(String prefix, String message) {
    if (kDebugMode) {
      print('$prefix $message');
    }
  }
}
