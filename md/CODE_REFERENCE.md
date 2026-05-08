# Code Reference - Fake OTP Implementation

## Quick Copy-Paste Reference

This document contains the key code sections for the fake OTP authentication system.

---

## 🔧 Core Authentication Service

### File: `lib/features/auth/services/auth_service.dart`

**Key Constants:**
```dart
static const String FAKE_OTP = '123456'; // Fixed OTP for development
static const String _isLoggedInKey = 'user_logged_in';
static const String _phoneNumberKey = 'user_phone_number';
```

**Main Methods:**
```dart
// Send OTP (simulates network call)
Future<void> sendOTP({
  required String phoneNumber,
  required Function(String verificationId, int? resendToken) onCodeSent,
  required Function(String errorMessage) onError,
}) async {
  try {
    await Future.delayed(const Duration(seconds: 1));
    onCodeSent('fake_verification_id_$phoneNumber', null);
  } catch (e) {
    onError('Failed to send OTP: ${e.toString()}');
  }
}

// Verify OTP against fixed OTP
Future<bool> verifyOTP({
  required String otp,
  required String phoneNumber,
  required Function(String errorMessage) onError,
}) async {
  try {
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (otp == FAKE_OTP) {
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

// Check if user is logged in
Future<bool> isUserLoggedIn() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  } catch (e) {
    return false;
  }
}

// Get current user's phone
Future<String?> getCurrentUserPhone() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneNumberKey);
  } catch (e) {
    return null;
  }
}

// Sign out
Future<void> signOut() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_phoneNumberKey);
  } catch (e) {
    // Handle error silently
  }
}

// Save login state
Future<void> _saveLoginState(String phoneNumber) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_phoneNumberKey, phoneNumber);
  } catch (e) {
    throw Exception('Failed to save login state: ${e.toString()}');
  }
}
```

---

## 📱 Phone Input Screen

### File: `lib/features/auth/screens/phone_input_screen.dart`

**Phone Validation:**
```dart
bool _isValidPhone(String phone) {
  final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
  return digitsOnly.length == 10;
}
```

**Send OTP Method:**
```dart
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

  final phoneNumber = _phoneController.text.replaceAll(RegExp(r'\D'), '');

  await _authService.sendOTP(
    phoneNumber: phoneNumber,
    onCodeSent: (verificationId, resendToken) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushNamed(
        '/otp',
        arguments: {
          'phoneNumber': phoneNumber,
          'verificationId': verificationId,
        },
      );
    },
    onError: (errorMessage) {
      setState(() {
        _isLoading = false;
        _errorMessage = errorMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage ?? 'An error occurred')),
      );
    },
  );
}
```

---

## 🔐 OTP Verification Screen

### File: `lib/features/auth/screens/otp_screen.dart`

**OTP Verification Logic:**
```dart
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
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/home', (route) => false);
    }
  } else {
    setState(() => _isLoading = false);
  }
}
```

---

## 🏠 Home Screen

### File: `lib/features/auth/screens/home_screen.dart`

**Load User Phone:**
```dart
@override
void initState() {
  super.initState();
  _loadUserPhone();
  _startOfferCycle();
}

Future<void> _loadUserPhone() async {
  final phone = await _authService.getCurrentUserPhone();
  setState(() {
    _userPhone = phone ?? 'Shopper';
  });
}
```

**Logout Method (already exists):**
```dart
void _logout() async {
  await _authService.signOut();
  if (mounted) {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
}
```

---

## 🔄 App Navigation

### File: `lib/app.dart`

**AuthWrapper with Login State Check:**
```dart
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<bool> _isLoggedInFuture;

  @override
  void initState() {
    super.initState();
    _isLoggedInFuture = AuthService().isUserLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const PhoneInputScreen();
        }

        final isLoggedIn = snapshot.data ?? false;
        return isLoggedIn ? const HomeScreen() : const PhoneInputScreen();
      },
    );
  }
}
```

---

## 📦 Dependencies

### File: `pubspec.yaml`

**Added Dependency:**
```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8
  firebase_core: ^3.1.1
  firebase_auth: ^5.1.1
  cloud_firestore: ^5.0.2
  go_router: ^13.0.0
  google_fonts: ^8.1.0
  shared_preferences: ^2.2.2  # ✨ NEW
```

---

## 🔄 Firebase Migration Code Snippets

When ready to switch to Firebase, replace methods in `auth_service.dart`:

### Replace sendOTP():
```dart
Future<void> sendOTP({
  required String phoneNumber,
  required Function(String verificationId, int? resendToken) onCodeSent,
  required Function(String errorMessage) onError,
}) async {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  try {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      timeout: const Duration(seconds: 120),
    );
  } catch (e) {
    onError(e.toString());
  }
}
```

### Replace verifyOTP():
```dart
Future<bool> verifyOTP({
  required String otp,
  required String phoneNumber,
  required String verificationId,
  required Function(String errorMessage) onError,
}) async {
  try {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    UserCredential userCredential = await _auth.signInWithCredential(credential);
    await _saveLoginState(userCredential.user!.phoneNumber ?? phoneNumber);
    return true;
  } catch (e) {
    onError(e.toString());
    return false;
  }
}
```

---

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────┐
│   Phone Input Screen                │
│   - Validate 10-digit number        │
│   - Call authService.sendOTP()      │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│   AuthService.sendOTP()             │
│   - Simulate 1 second delay         │
│   - Call onCodeSent() callback      │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│   Navigate to OTP Screen            │
│   - Pass phoneNumber                │
│   - Pass verificationId             │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│   OTP Screen                        │
│   - User enters 6 digits            │
│   - Call authService.verifyOTP()    │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│   AuthService.verifyOTP()           │
│   - Check if OTP == "123456"        │
│   - Save to SharedPreferences       │
│   - Return true/false               │
└─────────────────────────────────────┘
                  ↓
            ┌─────┴─────┐
            ↓           ↓
        Success      Failure
            ↓           ↓
         Home      Error Message
        Screen       (Try Again)
```

---

## 🧪 Testing Code Snippets

```dart
// Test successful login
testWidgets('Login with correct OTP', (WidgetTester tester) async {
  await tester.pumpWidget(const SLVHApp());
  
  // Enter phone number
  await tester.enterText(find.byType(TextField).first, '9876543210');
  
  // Tap send OTP button
  await tester.tap(find.text('Send OTP'));
  await tester.pumpAndSettle();
  
  // Enter OTP
  List<TextField> otpBoxes = find.byType(TextField).evaluate()
      .map((widget) => widget.widget as TextField).toList();
  
  for (int i = 0; i < 6; i++) {
    await tester.enterText(find.byWidget(otpBoxes[i]), '123456'[i]);
  }
  
  // Tap verify button
  await tester.tap(find.text('Verify & Continue'));
  await tester.pumpAndSettle();
  
  // Expect to be on home screen
  expect(find.byType(HomeScreen), findsOneWidget);
});

// Test invalid OTP
testWidgets('Show error for incorrect OTP', (WidgetTester tester) async {
  // ... setup code ...
  
  // Enter wrong OTP
  await tester.enterText(find.byType(TextField), '000000');
  
  // Tap verify
  await tester.tap(find.text('Verify & Continue'));
  await tester.pumpAndSettle();
  
  // Expect error message
  expect(find.text('Invalid OTP. Hint: Use 123456 for development'), findsOneWidget);
});
```

---

## ✨ Key Points

| Aspect | Detail |
|--------|--------|
| **Fixed OTP** | `123456` (hardcoded) |
| **Phone Validation** | Must be 10 digits |
| **OTP Length** | Must be exactly 6 digits |
| **Storage** | SharedPreferences |
| **Delay Simulation** | 1 sec for sendOTP, 0.8 sec for verifyOTP |
| **Error Message** | "Invalid OTP. Hint: Use 123456 for development" |
| **Session** | Persists across app restarts |
| **Logout** | Clears SharedPreferences |

---

**This reference document covers all the key code sections needed for the fake OTP system.**

See **FAKE_OTP_GUIDE.md** for migration to Firebase.
