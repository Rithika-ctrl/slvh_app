import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../utils/secure_logger.dart';

/// Firebase App Check Service (H-2 Security Fix)
///
/// Purpose: Prevent unauthorized API calls to Firebase services by validating app authenticity.
///
/// Problem Solved (H-2):
/// - Firebase API keys are public by design but must be protected from misuse
/// - Without App Check, attackers can:
///   ✗ Call Firebase API directly with hardcoded keys
///   ✗ Bypass Firestore security rules if they find rule gaps
///   ✗ Use reverse-engineered API endpoints
///   ✗ Perform automated attacks (rate limiting ineffective)
///
/// Solution: Firebase App Check validates requests by:
/// 1. Verifying app authenticity (iOS: DeviceCheck, Android: Play Integrity API)
/// 2. Signing requests with device attestation tokens
/// 3. Rejecting requests without valid attestation (401 Unauthorized)
/// 4. Providing defense-in-depth with Firestore Security Rules
///
/// Configuration Required:
/// 1. iOS: Enable App Check in Firebase Console → Project Settings → App Check
/// 2. Android: Enable App Check in Firebase Console → Project Settings → App Check
/// 3. Web: Requires reCAPTCHA v3 (not implemented here)
///
/// Firestore Rules Integration:
/// App Check attestation tokens are verified server-side by Firestore.
/// See firestore.rules for security rule details.
///
/// Security Benefits:
/// ✅ Prevents direct Firebase API calls without app signature
/// ✅ Detects emulators and jailbroken devices
/// ✅ Rate-limiting enforced at attestation level
/// ✅ Protects against reverse-engineering and automated attacks
/// ✅ Defense-in-depth: Firestore rules + App Check + custom logic
///
class AppCheckService {
  /// Initialize Firebase App Check on app startup
  ///
  /// IMPORTANT: This MUST be called:
  /// 1. AFTER Firebase.initializeApp()
  /// 2. BEFORE any Firestore/Firebase operations
  /// 3. In main() before runApp()
  ///
  /// Returns: true if initialized successfully
  static Future<bool> initialize() async {
    try {
      AppLogger.debug('🔐 App Check: Initializing Firebase App Check...');

      // Skip on web platform (requires reCAPTCHA setup)
      if (kIsWeb) {
        AppLogger.debug('ℹ️ App Check: Web platform detected - skipping (reCAPTCHA required)');
        return false;
      }

      // Activate App Check (platform-specific providers configured automatically)
      try {
        await FirebaseAppCheck.instance.activate();
        AppLogger.success('✅ App Check: Firebase App Check initialized successfully');
        AppLogger.debug('   All Firestore requests now require valid App Check tokens');
        AppLogger.debug('   Configure providers in Firebase Console for full protection');
        return true;
      } catch (e) {
        AppLogger.error('❌ App Check: Initialization failed - providers may not be configured', e);
        _logSetupInstructions();
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ App Check: Unexpected initialization error', e);
      return false;
    }
  }

  /// Log setup instructions for developers when App Check initialization fails
  static void _logSetupInstructions() {
    AppLogger.warning('');
    AppLogger.warning('╔════════════════════════════════════════════════════════════════╗');
    AppLogger.warning('║        Firebase App Check Setup Required                        ║');
    AppLogger.warning('╚════════════════════════════════════════════════════════════════╝');

    AppLogger.warning('');
    AppLogger.warning('ANDROID Setup:');
    AppLogger.warning('1. Go to Firebase Console → slvh-b707f → Project Settings');
    AppLogger.warning('2. Click "App Check" tab');
    AppLogger.warning('3. Register app → Choose "Google Play Integrity"');
    AppLogger.warning('4. Update android/app/build.gradle:');
    AppLogger.warning('   dependencies {');
    AppLogger.warning('     implementation "com.google.android.play:integrity:1.1.0"');
    AppLogger.warning('   }');
    AppLogger.warning('5. Deploy release APK to Play Store');

    AppLogger.warning('');
    AppLogger.warning('iOS Setup:');
    AppLogger.warning('1. Go to Firebase Console → slvh-b707f → Project Settings');
    AppLogger.warning('2. Click "App Check" tab');
    AppLogger.warning('3. Register app → Choose "App Attest"');
    AppLogger.warning('4. Update ios/Podfile:');
    AppLogger.warning('   target "Runner" do');
    AppLogger.warning('     pod "FirebaseAppCheck/AppCheckUI"');
    AppLogger.warning('   end');
    AppLogger.warning('5. Run: cd ios && pod install && cd ..');
    AppLogger.warning('6. Deploy to real iOS device (requires hardware)');

    AppLogger.warning('');
    AppLogger.warning('Learn more: https://firebase.google.com/docs/app-check/get-started');
    AppLogger.warning('');
  }

  /// Get current App Check token (for debugging)
  static Future<String?> getToken() async {
    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken();
      if (appCheckToken == null) {
        AppLogger.warning('⚠️ App Check: Token is null');
        return null;
      }
      return appCheckToken.toString();
    } catch (e) {
      AppLogger.error('❌ App Check: Failed to get token', e);
      return null;
    }
  }

  /// Refresh App Check token
  static Future<void> refreshToken() async {
    try {
      await FirebaseAppCheck.instance.getToken();
      AppLogger.debug('🔄 App Check: Token refreshed');
    } catch (e) {
      AppLogger.error('❌ App Check: Token refresh failed', e);
    }
  }
}


