import 'package:shared_preferences/shared_preferences.dart';

/// FAKE OTP Authentication Service
/// 
/// This service uses a FAKE OTP system (123456) for development purposes.
/// 
/// TO REPLACE WITH REAL FIREBASE OTP:
/// 1. Import firebase_auth package
/// 2. Replace _sendFakeOTP() with Firebase verifyPhoneNumber()
/// 3. Replace _verifyFakeOTP() with Firebase credential verification
/// 4. Update error handling as needed
/// 
class AuthService {
  // ============= FAKE OTP CONSTANTS =============
  // TODO: Replace these with Firebase configuration when needed
  static const String FAKE_OTP = '123456'; // Fixed OTP for development
  
  // Storage keys
  static const String _isLoggedInKey = 'user_logged_in';
  static const String _phoneNumberKey = 'user_phone_number';

  // ============= PUBLIC METHODS =============

  /// Simulate sending OTP to phone number
  /// In real Firebase, this would call verifyPhoneNumber()
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Simulate OTP sent successfully
      // In real Firebase: the onCodeSent callback gets called by Firebase
      onCodeSent('fake_verification_id_$phoneNumber', null);
    } catch (e) {
      onError('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verify OTP against the fixed FAKE_OTP
  /// In real Firebase, this would create PhoneAuthCredential and sign in
  Future<bool> verifyOTP({
    required String otp,
    required String phoneNumber,
    required Function(String errorMessage) onError,
  }) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Check if OTP matches the fixed OTP
      if (otp == FAKE_OTP) {
        // Save login state to SharedPreferences
        await _saveLoginState(phoneNumber);
        return true;
      } else {
        onError('Invalid OTP. Hint: Use 123456 for development');
        return false;
      }
    } catch (e) {
      onError('Verification failed: ${e.toString()}');
      return false;
    }
  }

  /// Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get current user's phone number
  Future<String?> getCurrentUserPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_phoneNumberKey);
    } catch (e) {
      return null;
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_phoneNumberKey);
      await prefs.remove(_adminLoginKey);
      await prefs.remove(_adminEmailKey);
    } catch (e) {
      // Handle error silently
    }
  }

  // ============= ADMIN LOGIN (FAKE - FOR DEVELOPMENT) =============

  static const String _adminLoginKey = 'admin_logged_in';
  static const String _adminEmailKey = 'admin_email';
  
  // Fake admin credentials (for development only)
  static const String FAKE_ADMIN_EMAIL = 'admin@smartshop.com';
  static const String FAKE_ADMIN_PASSWORD = 'admin123';

  /// Admin login with email and password (FAKE - for development)
  /// In production, replace with Firebase Authentication
  Future<bool> adminLogin({
    required String email,
    required String password,
    required Function(String errorMessage) onError,
  }) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Fake admin verification
      if (email == FAKE_ADMIN_EMAIL && password == FAKE_ADMIN_PASSWORD) {
        // Save admin login state
        await _saveAdminLoginState(email);
        return true;
      } else {
        onError('Invalid email or password');
        return false;
      }
    } catch (e) {
      onError('Login failed: ${e.toString()}');
      return false;
    }
  }

  /// Check if admin is logged in
  Future<bool> isAdminLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_adminLoginKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get current admin email
  Future<String?> getCurrentAdminEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_adminEmailKey);
    } catch (e) {
      return null;
    }
  }

  // ============= PRIVATE METHODS =============

  /// Save login state to SharedPreferences
  Future<void> _saveLoginState(String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_phoneNumberKey, phoneNumber);
    } catch (e) {
      throw Exception('Failed to save login state: ${e.toString()}');
    }
  }

  /// Save admin login state to SharedPreferences
  Future<void> _saveAdminLoginState(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adminLoginKey, true);
      await prefs.setString(_adminEmailKey, email);
    } catch (e) {
      throw Exception('Failed to save admin login state: ${e.toString()}');
    }
  }

  // ============= FIREBASE MIGRATION GUIDE =============
  /*
   * When ready to switch to real Firebase OTP:
   * 
   * 1. Add this to sendOTP():
   *    final FirebaseAuth _auth = FirebaseAuth.instance;
   *    await _auth.verifyPhoneNumber(
   *      phoneNumber: phoneNumber,
   *      verificationCompleted: (PhoneAuthCredential credential) async {
   *        await _auth.signInWithCredential(credential);
   *      },
   *      verificationFailed: (FirebaseAuthException e) {
   *        onError(e.message ?? 'Verification failed');
   *      },
   *      codeSent: (String verificationId, int? resendToken) {
   *        onCodeSent(verificationId, resendToken);
   *      },
   *      codeAutoRetrievalTimeout: (String verificationId) {},
   *      timeout: const Duration(seconds: 120),
   *    );
   * 
   * 2. Replace verifyOTP() with:
   *    PhoneAuthCredential credential = PhoneAuthProvider.credential(
   *      verificationId: verificationId,
   *      smsCode: otp,
   *    );
   *    UserCredential userCredential = await _auth.signInWithCredential(credential);
   *    await _saveLoginState(userCredential.user!.phoneNumber ?? phoneNumber);
   *    return true;
   */
}

