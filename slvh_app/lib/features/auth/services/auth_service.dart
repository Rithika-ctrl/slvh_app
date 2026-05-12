import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/auth/services/otp_resend_service.dart';
import 'package:slvh_app/features/notifications/services/notification_service.dart';

/// Real Firebase Authentication Service
///
/// Customer login  → Firebase Phone Auth (SMS OTP)
/// Admin login     → Firebase Email/Password Auth
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final OTPResendService _otpResendService = OTPResendService();

  // ─── Storage keys ────────────────────────────────────────────
  static const String _isLoggedInKey   = 'user_logged_in';
  static const String _phoneNumberKey  = 'user_phone_number';
  static const String _adminLoginKey   = 'admin_logged_in';
  static const String _adminEmailKey   = 'admin_email';

  // ─── Admin e-mail whitelist ───────────────────────────────────
  // Real admin accounts must exist in Firebase Authentication.
  static const List<String> _adminEmailWhitelist = [
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
          onError(e.message ?? 'Phone verification failed.');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onError('Failed to send OTP: ${e.toString()}');
    }
  }

  Future<bool> verifyOTP({
    required String otp,
    required String phoneNumber,
    String verificationId = '',
    required Function(String errorMessage) onError,
  }) async {
    try {
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
      print('📲 Attempting OTP resend for $phoneNumber...');

      // STEP 1: Check rate limiting via OTPResendService
      await _otpResendService.requestResend(
        phoneNumber: phoneNumber,
        onError: (msg) => onError(msg),
      );

      // STEP 2: Resend via Firebase (throttling already enforced)
      final normalised = phoneNumber.startsWith('+')
          ? phoneNumber
          : '+91${phoneNumber.replaceAll(RegExp(r'\D'), '')}';

      await _auth.verifyPhoneNumber(
        phoneNumber: normalised,
        timeout: const Duration(seconds: 120),
        resendToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final result = await _auth.signInWithCredential(credential);
            final phone = result.user?.phoneNumber ?? normalised;
            await _saveCustomerSession(phone);
            print('✅ OTP auto-verified during resend');
          } catch (_) {}
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Phone verification failed.');
        },
        codeSent: (String verificationId, int? newResendToken) {
          print('✅ OTP resent successfully for $normalised');
          onCodeSent(verificationId, newResendToken);
        },
        codeAutoRetrievalTimeout: (_) {},
      );

      return true;
    } on OTPResendException catch (e) {
      // Rate limiting error
      print('❌ OTP resend rate-limited: ${e.message}');
      onError(e.message);
      rethrow;
    } catch (e) {
      final msg = 'Failed to resend OTP: ${e.toString()}';
      print('❌ $msg');
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

      if (!_adminEmailWhitelist
          .any((e) => e.toLowerCase() == signedInEmail.toLowerCase())) {
        await _auth.signOut();
        onError('This account does not have admin access.');
        return false;
      }

      await _saveAdminSession(signedInEmail);
      return true;
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
      if (_adminEmailWhitelist
          .any((e) => e.toLowerCase() == email.toLowerCase())) {
        return true;
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
    } catch (e) {
      throw Exception('Failed to save admin session: ${e.toString()}');
    }
  }
}
