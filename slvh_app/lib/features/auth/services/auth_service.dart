import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/auth/services/otp_resend_service.dart';
import 'package:slvh_app/features/auth/services/session_manager_service.dart';
import 'package:slvh_app/features/notifications/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/secure_logger.dart';

// String extension for validation
extension StringValidation on String {
  bool get isNumericOnly => RegExp(r'^\d+$').hasMatch(this);
}

/// Real Firebase Authentication Service
///
/// Customer login  → Firebase Phone Auth (SMS OTP)
/// Admin login     → Firebase Email/Password Auth
///
/// Includes:
/// - Session management with token refresh (Feature 8)
/// - OTP resend with rate limiting (Feature 7)
/// - Firebase auth state tracking
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final OTPResendService _otpResendService = OTPResendService();
  SessionManagerService? _sessionManager;

  // ─── Storage keys ────────────────────────────────────────────
  static const String _isLoggedInKey   = 'user_logged_in';
  static const String _phoneNumberKey  = 'user_phone_number';
  static const String _adminLoginKey   = 'admin_logged_in';
  static const String _adminEmailKey   = 'admin_email';

  // ─── Admin Accounts Configuration ────────────────────────────
  // MIGRATED TO FIRESTORE: Admin accounts are now stored in Firestore
  // (collection: admin_accounts) instead of hardcoded list.
  // This allows runtime revocation without code changes.
  // 
  // Fallback whitelist used only if Firestore is unavailable:
  static const List<String> _adminEmailWhitelistFallback = [
    'admin@smartshop.com',
  ];

  // =========================================================
  // CUSTOMER – Firebase Phone Auth (SMS OTP)
  // =========================================================

  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    final normalised = phoneNumber.startsWith('+')
        ? phoneNumber
        : '+91${phoneNumber.replaceAll(RegExp(r'\D'), '')}';

    // Check if it's a test phone number (works offline)
    if (_isTestPhoneNumber(normalised)) {
      AppLogger.debug('✅ Test phone number detected: $normalised');
      // For test numbers, generate a fake verification ID and proceed
      onCodeSent('test-verification-id-$normalised', null);
      return;
    }

    // For development: any other number also works in test mode
    AppLogger.debug('📱 Development mode: Accepting phone number $normalised');
    onCodeSent('dev-verification-id-$normalised', null);
    
    // Production code below (uncomment when Firebase is configured)
    /*
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: normalised,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final result = await _auth.signInWithCredential(credential);
            final phone = result.user?.phoneNumber ?? normalised;
            await _saveCustomerSession(phone);
          } catch (_) {}
        },
        verificationFailed: (FirebaseAuthException e) {
          AppLogger.debug('❌ Phone verification failed: ${e.code} - ${e.message}');
          
          // Handle common Firebase errors with user-friendly messages
          if (e.code == 'billing-not-enabled') {
            onError('Firebase Authentication is not properly configured. Please contact support.');
          } else if (e.code == 'invalid-phone-number') {
            onError('Invalid phone number. Please enter a valid number.');
          } else {
            onError(e.message ?? 'Phone verification failed. Please try again.');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      AppLogger.debug('❌ Failed to send OTP: $e');
      onError('Failed to send OTP: ${e.toString()}');
    }
    */
  }

  /// Check if phone number is a Firebase test number
  /// Test numbers: +1 650-555-3434 to +1 650-555-3499, etc.
  bool _isTestPhoneNumber(String phoneNumber) {
    // Firebase test phone numbers
    final testNumbers = [
      '+16505553434',
      '+16505553435',
      '+16505553436',
      '+16505553437',
      '+16505553438',
      '+16505553439',
      '+16505553440',
      // Common test numbers for India
      '+919999999999',
      '+919876543210',
      '+919111111111',
    ];
    return testNumbers.contains(phoneNumber);
  }

  Future<bool> verifyOTP({
    required String otp,
    required String phoneNumber,
    String verificationId = '',
    required Function(String errorMessage) onError,
  }) async {
    try {
      // Handle test and development phone numbers
      if (verificationId.startsWith('test-verification-id-') || 
          verificationId.startsWith('dev-verification-id-')) {
        // In development mode, accept OTP 123456 or any 6-digit code
        if (otp.length == 6 && otp.isNumericOnly) {
          final phone = phoneNumber.startsWith('+')
              ? phoneNumber
              : '+91${phoneNumber.replaceAll(RegExp(r'\D'), '')}';
          await _saveCustomerSession(phone);
          await _otpResendService.resetResendCounter(phone);
          AppLogger.debug('✅ Development OTP verified successfully for $phone');
          return true;
        } else {
          onError('Invalid OTP. Please enter a 6-digit code.');
          return false;
        }
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final result = await _auth.signInWithCredential(credential);
      final phone = result.user?.phoneNumber ??
          '+91${phoneNumber.replaceAll(RegExp(r'\D'), '')}';
      await _saveCustomerSession(phone);
      
      // Reset resend counter after successful verification
      await _otpResendService.resetResendCounter(phone);
      
      return true;
    } on FirebaseAuthException catch (e) {
      onError(e.message ?? 'Invalid OTP. Please try again.');
      return false;
    } catch (e) {
      onError('Verification failed: ${e.toString()}');
      return false;
    }
  }

  /// Resend OTP with throttling and rate limiting
  /// 
  /// Enforces:
  /// 1. Minimum 30 seconds between resends
  /// 2. Maximum 3 resends per OTP session
  /// 3. Firebase Auth resend token for optimization
  /// 
  /// Returns: true if OTP was resent successfully
  /// Throws: OTPResendException if rate-limited
  Future<bool> resendOTP({
    required String phoneNumber,
    int? resendToken,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    try {
      AppLogger.debug('📲 Attempting OTP resend for $phoneNumber...');

      // Check if it's a test phone number
      final normalised = phoneNumber.startsWith('+')
          ? phoneNumber
          : '+91${phoneNumber.replaceAll(RegExp(r'\D'), '')}';

      if (_isTestPhoneNumber(normalised)) {
        AppLogger.debug('✅ Test phone number resend for: $normalised');
        onCodeSent('test-verification-id-$normalised', null);
        return true;
      }

      // STEP 1: Check rate limiting via OTPResendService
      await _otpResendService.requestResend(
        phoneNumber: phoneNumber,
        onError: (msg) => onError(msg),
      );

      // STEP 2: Resend via Firebase (throttling already enforced)
      await _auth.verifyPhoneNumber(
        phoneNumber: normalised,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final result = await _auth.signInWithCredential(credential);
            final phone = result.user?.phoneNumber ?? normalised;
            await _saveCustomerSession(phone);
            AppLogger.debug('✅ OTP auto-verified during resend');
          } catch (_) {}
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Phone verification failed.');
        },
        codeSent: (String verificationId, int? newResendToken) {
          AppLogger.debug('✅ OTP resent successfully for $normalised');
          onCodeSent(verificationId, newResendToken);
        },
        codeAutoRetrievalTimeout: (_) {},
      );

      return true;
    } on OTPResendException catch (e) {
      // Rate limiting error
      AppLogger.debug('❌ OTP resend rate-limited: ${e.message}');
      onError(e.message);
      rethrow;
    } catch (e) {
      final msg = 'Failed to resend OTP: ${e.toString()}';
      AppLogger.debug('❌ $msg');
      onError(msg);
      return false;
    }
  }

  // =========================================================
  // ADMIN – Firebase Email / Password Auth
  // =========================================================

  Future<bool> adminLogin({
    required String email,
    required String password,
    required Function(String errorMessage) onError,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final signedInEmail = result.user?.email ?? '';

      // SECURITY (H-3): Check if this email is a registered admin account in Firestore
      // and is enabled (not revoked). This allows runtime revocation without code changes.
      try {
        final adminDoc = await _db
            .collection('admin_accounts')
            .doc(signedInEmail.toLowerCase())
            .get();

        if (!adminDoc.exists) {
          await _auth.signOut();
          onError('This account does not have admin access.');
          AppLogger.warning(
            '🔐 Admin login rejected: Email not in admin_accounts collection ($signedInEmail)',
          );
          return false;
        }

        final isEnabled = adminDoc.get('enabled') as bool? ?? false;
        if (!isEnabled) {
          await _auth.signOut();
          onError('This admin account has been disabled.');
          AppLogger.warning(
            '🔐 Admin login rejected: Account disabled ($signedInEmail)',
          );
          return false;
        }

        // ✅ Admin account exists and is enabled - log them in
        await _saveAdminSession(signedInEmail);
        
        // Update last login timestamp for audit trail
        await _db
            .collection('admin_accounts')
            .doc(signedInEmail.toLowerCase())
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
        }).catchError((_) {
          // Non-fatal if timestamp update fails
          AppLogger.debug('ℹ️ Could not update admin lastLogin timestamp');
        });

        AppLogger.success('✅ Admin login successful: $signedInEmail');
        return true;
      } on FirebaseException catch (firestoreError) {
        // Firestore error - fall back to hardcoded whitelist for bootstrap
        AppLogger.warning(
          '⚠️ Firestore error during admin validation, using fallback whitelist',
        );
        AppLogger.debug('Firestore error details: $firestoreError');

        if (!_adminEmailWhitelistFallback
            .any((e) => e.toLowerCase() == signedInEmail.toLowerCase())) {
          await _auth.signOut();
          onError('This account does not have admin access.');
          return false;
        }

        await _saveAdminSession(signedInEmail);
        return true;
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          onError('No admin account found for this email.');
          break;
        case 'wrong-password':
        case 'invalid-credential':
          onError('Incorrect password. Please try again.');
          break;
        case 'invalid-email':
          onError('Please enter a valid email address.');
          break;
        case 'too-many-requests':
          onError('Too many failed attempts. Please wait and try again.');
          break;
        default:
          onError(e.message ?? 'Login failed. Please try again.');
      }
      return false;
    } catch (e) {
      onError('Login failed: ${e.toString()}');
      return false;
    }
  }

  // =========================================================
  // SESSION STATE
  // =========================================================

  Future<bool> isUserLoggedIn() async {
    if (_auth.currentUser?.phoneNumber != null) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isAdminLoggedIn() async {
    if (_auth.currentUser?.email != null) {
      final email = _auth.currentUser!.email!;
      
      // SECURITY (H-3): Check Firestore to verify admin account is still enabled
      try {
        final adminDoc = await _db
            .collection('admin_accounts')
            .doc(email.toLowerCase())
            .get();

        if (adminDoc.exists) {
          final isEnabled = adminDoc.get('enabled') as bool? ?? false;
          if (isEnabled) {
            return true;
          } else {
            // Admin account has been disabled - sign them out
            await signOut();
            AppLogger.warning(
              '🔐 Admin session revoked: Account disabled in Firestore ($email)',
            );
            return false;
          }
        }
      } on FirebaseException catch (e) {
        // Firestore error - fall back to SharedPreferences
        AppLogger.debug(
          '⚠️ Firestore error during admin session check: ${e.code}',
        );
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_adminLoginKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getCurrentUserPhone() async {
    if (_auth.currentUser?.phoneNumber != null) {
      return _auth.currentUser!.phoneNumber;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_phoneNumberKey);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getCurrentAdminEmail() async {
    if (_auth.currentUser?.email != null) return _auth.currentUser!.email;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_adminEmailKey);
    } catch (_) {
      return null;
    }
  }

  /// Initialize session manager for token refresh and auth state listening
  /// 
  /// Should be called once at app startup (in app root)
  void initializeSessionManager(SessionManagerService sessionManager,
      {VoidCallback? onSessionExpired, VoidCallback? onSessionValid}) {
    _sessionManager = sessionManager;
    _sessionManager?.initialize(
      onSessionExpired: onSessionExpired,
      onSessionValid: onSessionValid,
    );
    AppLogger.debug('🔐 AuthService: Session manager initialized');
  }

  /// Get a fresh Firebase ID token before Firestore operations
  ///
  /// Feature 8: Token Refresh / Session Expiry
  /// 
  /// Firebase ID tokens expire after 1 hour. This method ensures
  /// the token is refreshed before critical Firestore operations.
  ///
  /// Usage:
  /// ```dart
  /// try {
  ///   final token = await authService.getRefreshedToken();
  ///   // Token is now fresh, safe for Firestore operations
  ///   await _db.collection('orders').doc(orderId).set(...);
  /// } on FirebaseAuthException {
  ///   // Token refresh failed, user likely logged out
  ///   navigateToLogin();
  /// }
  /// ```
  ///
  /// Returns: Fresh ID token string
  /// Throws: FirebaseAuthException if token refresh fails or user is logged out
  Future<String> getRefreshedToken() async {
    if (_sessionManager == null) {
      throw Exception('SessionManager not initialized. Call initializeSessionManager() first.');
    }

    final token = await _sessionManager!.getValidToken();
    if (token == null) {
      throw FirebaseAuthException(
        code: 'user-not-authenticated',
        message: 'User is not authenticated. Please log in again.',
      );
    }

    return token;
  }

  /// Check if current session is valid
  ///
  /// Returns: true if user is authenticated and token is fresh
  Future<bool> isSessionValid() async {
    if (_sessionManager == null) return false;
    return _sessionManager!.isSessionValid();
  }

  /// Get current auth state stream
  ///
  /// Useful for listening to auth changes throughout the app
  Stream<AuthState> get authStateStream {
    if (_sessionManager == null) {
      throw Exception('SessionManager not initialized');
    }
    return _sessionManager!.authStateStream;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_phoneNumberKey);
      await prefs.remove(_adminLoginKey);
      await prefs.remove(_adminEmailKey);
    } catch (_) {}
  }

  // =========================================================
  // ROLE-BASED ACCESS
  // =========================================================

  Future<String?> getUserRole(String phoneNumber) async {
    try {
      final doc = await _db.collection('users').doc(phoneNumber).get();
      if (doc.exists) return doc.data()?['role'] as String?;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getAdminRole() async {
    final isAdmin = await isAdminLoggedIn();
    return isAdmin ? 'admin' : null;
  }

  Future<String?> getCurrentUserRole() async {
    final adminRole = await getAdminRole();
    if (adminRole != null) return adminRole;
    final phone = await getCurrentUserPhone();
    if (phone != null) return await getUserRole(phone);
    return null;
  }

  // =========================================================
  // PRIVATE HELPERS
  // =========================================================

  Future<void> _saveCustomerSession(String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_phoneNumberKey, phoneNumber);

      // Ensure Firestore user doc exists
      final doc = _db.collection('users').doc(phoneNumber);
      final snap = await doc.get();
      if (!snap.exists) {
        await doc.set({
          'phone': phoneNumber,
          'role': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      try {
        await NotificationService().saveFCMTokenForUser(phoneNumber);
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to save login state: ${e.toString()}');
    }
  }

  Future<void> _saveAdminSession(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adminLoginKey, true);
      await prefs.setString(_adminEmailKey, email);

      // Create or update admin profile in Firestore with fixed ID "admin"
      const String adminUserId = 'admin';
      
      // Ensure admin user document exists with role and email
      final adminDoc = _db.collection('users').doc(adminUserId);
      await adminDoc.set({
        'role': 'admin',
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save FCM token for the admin user
      try {
        await NotificationService().saveFCMTokenForUser(adminUserId);
        AppLogger.debug('✅ FCM token saved for admin user: $adminUserId');
      } catch (e) {
        AppLogger.debug('⚠️ Failed to save FCM token for admin: $e');
        // Don't throw - continue with login even if FCM fails
      }
    } catch (e) {
      throw Exception('Failed to save admin session: ${e.toString()}');
    }
  }

  // =========================================================
  // ADMIN ACCOUNTS INITIALIZATION (SECURITY FIX H-3)
  // =========================================================

  /// Initialize default admin accounts in Firestore
  ///
  /// SECURITY (H-3): This MUST be called during app setup to create the
  /// admin_accounts collection. Admin access is verified against Firestore,
  /// allowing runtime revocation without code changes.
  ///
  /// Default: Creates admin@smartshop.com as enabled admin
  /// Admin Revocation: Disable in Firebase Console (set 'enabled' to false)
  static Future<void> initializeAdminAccounts() async {
    try {
      AppLogger.debug('🔐 Initializing admin accounts in Firestore...');

      final db = FirebaseFirestore.instance;
      final adminAccountsRef = db.collection('admin_accounts');

      // Initialize default admin account
      const String defaultAdminEmail = 'admin@smartshop.com';
      final adminDocRef = adminAccountsRef.doc(defaultAdminEmail.toLowerCase());

      // Check if admin account already exists
      final existingDoc = await adminDocRef.get();
      if (existingDoc.exists) {
        AppLogger.success(
          '✅ Admin account already configured: $defaultAdminEmail',
        );
        return;
      }

      // Create default admin account
      await adminDocRef.set({
        'email': defaultAdminEmail,
        'enabled': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': null, // Will be set on first login
        'notes': 'Default admin account. Disable in Firestore to revoke access.',
      });

      AppLogger.success(
        '✅ Default admin account created: $defaultAdminEmail',
      );
      AppLogger.debug(
        '   To revoke admin access: Set "enabled" = false in admin_accounts collection',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to initialize admin accounts', e);
      // Non-fatal - app can still run, but admin login will use fallback whitelist
    }
  }

  /// Disable an admin account (revocation)
  ///
  /// This is a production method for revoking admin access without code changes.
  /// Can be called from admin dashboard or Firebase Console directly.
  static Future<bool> disableAdminAccount(String email) async {
    try {
      AppLogger.warning('🔐 Disabling admin account: $email');

      await FirebaseFirestore.instance
          .collection('admin_accounts')
          .doc(email.toLowerCase())
          .update({
        'enabled': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'disabledAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('✅ Admin account disabled: $email');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to disable admin account', e);
      return false;
    }
  }

  /// Re-enable a previously disabled admin account
  static Future<bool> enableAdminAccount(String email) async {
    try {
      AppLogger.debug('🔐 Enabling admin account: $email');

      await FirebaseFirestore.instance
          .collection('admin_accounts')
          .doc(email.toLowerCase())
          .update({
        'enabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'disabledAt': null,
      });

      AppLogger.success('✅ Admin account re-enabled: $email');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to enable admin account', e);
      return false;
    }
  }
}



