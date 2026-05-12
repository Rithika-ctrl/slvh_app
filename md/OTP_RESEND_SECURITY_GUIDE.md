# Feature 7: OTP Resend + Expiry Security Guide

## Problem Statement

The original OTP implementation had critical security gaps:

1. **No User-Facing Expiry Feedback**: Firebase silently expires OTP after 60 seconds, but users don't see this. If SMS delays occur, users retry with an expired code and get cryptic errors.
2. **No Resend Mechanism**: Customers stuck on login screen if initial SMS fails/delays. No way to request a new code.
3. **No Rate Limiting**: Attackers could spam "resend" requests, wasting SMS quota and increasing Firebase costs.
4. **Firebase Limits Ignored in UI**: Firebase allows max 3 resends per auth session, but this wasn't enforced in the app, risking session lockouts.

**Feature 7 addresses all four issues** through:
- Real-time countdown timer showing exact seconds until OTP expiry
- Resend button available after 30 seconds
- Database-level rate limiting (30s minimum between resends, max 3 attempts)
- Professional rate limit error messages with retry suggestions

---

## Architecture Overview

### Components

```
OTP Flow:
┌─────────────────┐
│ Customer        │
│ phone auth      │
└────────┬────────┘
         │
         ├─→ AuthService.requestOTP()
         │   └─→ Firebase Phone Auth (SMS sent, 60s expiry starts)
         │
         ├─→ OTPScreen (widget tree)
         │   ├─→ OTPCountdownTimer (visual feedback, 0-60s)
         │   ├─→ OTPResendStatus (attempt counter: "1 of 3")
         │   ├─→ 6-digit input boxes
         │   └─→ Resend button (enabled after 30s)
         │
         ├─→ On Resend:
         │   ├─→ OTPResendService.requestResend() (Firestore validation)
         │   │   ├─→ Check resend_at: is now - lastResend >= 30s?
         │   │   └─→ Check resend_count: is count < 3?
         │   │   └─→ Update Firestore: increment resend_count, set resend_at
         │   │
         │   └─→ AuthService.resendOTP() (Firebase Auth)
         │       └─→ Firebase Phone Auth (new SMS sent, new 60s timer)
         │
         └─→ On Verify:
             ├─→ AuthService.verifyOTP()
             │   └─→ Firebase verify (OTP validity check)
             │
             └─→ OTPResendService.resetResendCounter()
                 └─→ Firestore: clear resend_count, resend_at (session cleanup)
```

### Data Flow: Rate Limiting

**Firestore User Document** (users/{phoneNumber}):
```dart
{
  phone: "+919876543210",
  role: "customer",
  createdAt: Timestamp(2026-05-12 10:30:00),
  
  // OTP Resend Throttling Fields (NEW)
  resend_at: Timestamp(2026-05-12 10:35:42),      // When last resend was sent
  resend_count: 2,                                 // Attempt number (0-3)
  resend_at_formatted: "2026-05-12T10:35:42Z",    // ISO 8601 string
}
```

**Throttling Logic**:
1. User clicks "Resend" button
2. OTPResendService queries Firestore user doc
3. If `resend_at` exists:
   - Calculate `now - resend_at_timestamp`
   - If < 30 seconds: throw OTPResendException (rate limit error)
4. If `resend_count >= 3`: throw OTPResendException (max attempts exceeded)
5. If both checks pass: update Firestore with new `resend_at` + increment `resend_count`
6. Then call Firebase Auth resendPhoneNumber()

---

## File Structure

### New Files

#### `lib/features/auth/services/otp_resend_service.dart`

```dart
class OTPResendException implements Exception {
  final String message;
  final String code; // 'rate_limited', 'max_resends_exceeded'
  final int? retryAfterSeconds;
  
  OTPResendException({
    required this.message,
    required this.code,
    this.retryAfterSeconds,
  });
}

class OTPResendService {
  static const int resendMinimumIntervalSeconds = 30;
  static const int maxResendAttempts = 3;
  
  /// Enforce rate limiting BEFORE Firebase call
  Future<void> requestResend(String phoneNumber) async {
    // 1. Get user doc from Firestore
    // 2. Check if resend_at exists + validate 30s interval
    // 3. Check if resend_count < 3
    // 4. Update user doc with new resend_at + increment count
  }
  
  /// Reset attempt counter after successful OTP verification
  Future<void> resetResendCounter(String phoneNumber) async {
    // Set resend_count = 0 in Firestore
  }
  
  /// Get seconds remaining until next resend allowed
  Future<int> getResendWaitTime(String phoneNumber) async {
    // Calculate (resend_at + 30s) - now
  }
  
  /// Get current attempt number (0-3)
  Future<int> getResendCount(String phoneNumber) async {
    // Return resend_count from user doc
  }
  
  /// Clear all resend throttling on logout
  Future<void> clearOTPSession(String phoneNumber) async {
    // Set resend_at = null, resend_count = 0
  }
}
```

**Key Methods**:
- `requestResend(phoneNumber)`: Validates 30s interval + 3 max limit. Throws `OTPResendException` on violation.
- `resetResendCounter(phoneNumber)`: Called from AuthService after successful verification.
- `getResendWaitTime(phoneNumber)`: Returns seconds until next resend (0 if can resend now).
- `getResendCount(phoneNumber)`: Returns current attempt (0-3).
- `clearOTPSession(phoneNumber)`: Wipes resend fields on logout.

#### `lib/features/auth/widgets/otp_countdown_timer.dart`

```dart
class OTPCountdownTimer extends StatefulWidget {
  final int totalSeconds;              // Usually 60 (Firebase OTP expiry)
  final int resendAvailableAfter;      // Usually 30 seconds
  final VoidCallback onExpired;
  final VoidCallback onResendAvailable;
  final VoidCallback onResendTapped;
  final bool isResending;               // Show loading state
  
  @override
  State<OTPCountdownTimer> createState() => _OTPCountdownTimerState();
}

class _OTPCountdownTimerState extends State<OTPCountdownTimer>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _timeRemaining = 0;
  bool _resendAvailable = false;
  bool _expired = false;
  
  @override
  void initState() {
    super.initState();
    _timeRemaining = widget.totalSeconds;
    _startTimer();
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining--;
        
        // Resend available at 30s remaining
        if (_timeRemaining == widget.resendAvailableAfter &&
            !_resendAvailable) {
          _resendAvailable = true;
          widget.onResendAvailable();
        }
        
        // OTP expired at 0s
        if (_timeRemaining <= 0) {
          _expired = true;
          timer.cancel();
          widget.onExpired();
        }
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Timer display with color gradient
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getTimerColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getTimerColor(), width: 2),
          ),
          child: Column(
            children: [
              Text(
                '${_timeRemaining}s',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _getTimerColor(),
                ),
              ),
              if (_timeRemaining <= 10)
                Text(
                  'OTP expires soon',
                  style: TextStyle(color: AppColors.danger),
                )
              else if (!_resendAvailable)
                Text(
                  'Resend available in ${widget.resendAvailableAfter - (widget.totalSeconds - _timeRemaining)}s',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
            ],
          ),
        ),
        
        // Resend button
        if (_resendAvailable)
          ElevatedButton.icon(
            onPressed: widget.isResending ? null : widget.onResendTapped,
            icon: Icon(Icons.refresh),
            label: Text('Resend OTP'),
          ),
      ],
    );
  }
  
  Color _getTimerColor() {
    if (_expired) return AppColors.danger;
    if (_timeRemaining <= 10) return AppColors.orange;
    return AppColors.success;
  }
}

class OTPResendStatus extends StatelessWidget {
  final int currentAttempt;   // 0-3
  final int maxAttempts;       // 3
  final int? waitSeconds;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: currentAttempt >= 2
            ? AppColors.danger.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: currentAttempt >= 2 ? AppColors.danger : AppColors.warning),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attempt ${currentAttempt + 1} of $maxAttempts',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (currentAttempt >= 2)
                  Text(
                    'Last resend available. Next request in ${waitSeconds ?? 0}s',
                    style: TextStyle(fontSize: 12, color: AppColors.danger),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Key Features**:
- Timer color gradient: green (>10s) → orange (10s) → red (expired)
- Resend button auto-enables at 30s remaining
- OTPResendStatus shows "Attempt X of 3" with warnings
- Handles loading state during resend

#### `lib/features/auth/providers/auth_provider.dart`

Riverpod providers for reactive OTP state:

```dart
final authServiceProvider = Provider<AuthService>((_) => AuthService());
final otpResendServiceProvider = Provider<OTPResendService>((_) => OTPResendService());

// FutureProviders for real-time updates
final otpResendWaitTimeProvider = FutureProvider.family<int, String>((ref, phoneNumber) async {
  return ref.watch(otpResendServiceProvider).getResendWaitTime(phoneNumber);
});

final otpResendCountProvider = FutureProvider.family<int, String>((ref, phoneNumber) async {
  return ref.watch(otpResendServiceProvider).getResendCount(phoneNumber);
});

final canResendOTPProvider = FutureProvider.family<bool, String>((ref, phoneNumber) async {
  final count = await ref.watch(otpResendCountProvider(phoneNumber).future);
  return count < 3;
});
```

### Modified Files

#### `lib/features/auth/services/auth_service.dart`

**New Import**:
```dart
import 'package:slvh_app/features/auth/services/otp_resend_service.dart';
```

**New Field**:
```dart
final OTPResendService _otpResendService = OTPResendService();
```

**Enhanced `verifyOTP()` Method**:
```dart
// After successful verification, reset attempt counter
await _otpResendService.resetResendCounter(phone);
```

**New `resendOTP()` Method**:
```dart
Future<bool> resendOTP({
  required String phoneNumber,
  int? resendToken,
  required Function(String verificationId, int? resendToken) onCodeSent,
  required Function(String errorMessage) onError,
}) async {
  try {
    // 1. Validate rate limiting in Firestore
    await _otpResendService.requestResend(phoneNumber);
    
    // 2. Call Firebase Auth
    await _auth.verifyPhoneNumber(
      phoneNumber: _normalizePhoneNumber(phoneNumber),
      resendToken: resendToken,
      verificationCompleted: (PhoneAuthCredential credential) {
        // Auto-resolve on Android
      },
      verificationFailed: (FirebaseAuthException e) {
        onError('${e.code}: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
    
    return true;
  } on OTPResendException catch (e) {
    onError(e.message);
    return false;
  } on FirebaseAuthException catch (e) {
    onError('${e.code}: ${e.message}');
    return false;
  } catch (e) {
    onError('Unexpected error: $e');
    return false;
  }
}
```

#### `lib/features/auth/screens/otp_screen.dart`

**New State Fields**:
```dart
bool _isResending = false;
int _resendAttempts = 0;
bool _otpExpired = false;
int? _currentResendToken;
final OTPResendService _otpResendService = OTPResendService();
```

**Updated UI**:
```dart
OTPCountdownTimer(
  totalSeconds: 60,
  resendAvailableAfter: 30,
  onExpired: () => setState(() => _otpExpired = true),
  onResendTapped: _resendOTP,
  isResending: _isResending,
),

OTPResendStatus(
  currentAttempt: _resendAttempts,
  maxAttempts: 3,
),
```

#### `firestore.rules`

**Updated Comment**:
```rules
// Cloud Functions can write (for FCM token, notifications enabled, OTP resend throttling, etc.)
allow write: if isCloudFunction();
```

---

## Usage Flow

### Step 1: Initial OTP Request

```dart
// AuthService.requestOTP() called from phone auth screen
await _auth.verifyPhoneNumber(
  phoneNumber: "+919876543210",
  // ... Firebase callbacks
);
// User receives SMS with 6-digit code
// OTP valid for 60 seconds
```

### Step 2: User Sees OTP Screen

```dart
OTPCountdownTimer displays:
- 60 seconds countdown starts
- At 30s remaining: "Resend OTP" button becomes enabled
- At 10s remaining: Text turns orange
- At 0s: Text turns red, button disabled, "OTP expired" message
```

### Step 3: User Enters OTP (Success Path)

```dart
// User enters all 6 digits and taps "Verify & Continue"
_verifyOTP() {
  await _authService.verifyOTP(
    otp: "123456",
    verificationId: widget.verificationId,
    onError: (msg) { /* show error */ }
  );
  // On success:
  // 1. Firebase verifies OTP
  // 2. AuthService calls resetResendCounter()
  // 3. Firestore: resend_count = 0, resend_at = null
  // 4. User navigated to home
}
```

### Step 4: User Clicks Resend (Throttled Path)

```dart
_resendOTP() {
  // 1. OTPResendService.requestResend() called
  //    - Checks: now - resend_at >= 30s? ✓
  //    - Checks: resend_count < 3? ✓
  //    - Updates Firestore: resend_at=now, resend_count+=1
  
  // 2. AuthService.resendOTP() called
  //    - Calls Firebase Auth with resendToken
  //    - New SMS sent
  //    - New 60s countdown starts
  
  // 3. UI updates:
  //    - OTP input cleared
  //    - Timer reset to 60s
  //    - Resend attempt counter incremented
  //    - "OTP resent! Wait 30s before next resend" SnackBar shown
}
```

### Step 5: Rate Limit Hit

**Scenario A: Resend too soon**
```dart
// User clicks resend at 10 seconds after last resend
OTPResendService.requestResend() throws OTPResendException:
  message: "Please wait 20 seconds before requesting another OTP"
  code: "rate_limited"
  retryAfterSeconds: 20

// UI displays error SnackBar (orange background)
// User sees: "Please wait 20 seconds before requesting another OTP"
```

**Scenario B: Max resends exceeded**
```dart
// User has already resent 3 times (resend_count = 3)
OTPResendService.requestResend() throws OTPResendException:
  message: "Maximum resend attempts exceeded (3). Please contact support."
  code: "max_resends_exceeded"

// UI displays error SnackBar (orange background)
// OTPResendStatus shows: "Attempt 3 of 3 - Last resend available"
```

---

## Testing Scenarios

### Test 1: Normal Flow
1. Request OTP → Firebase sends SMS
2. OTP Screen shows countdown (60 → 0)
3. Enter OTP within 60s
4. Verify button tapped
5. **Expected**: User logged in, redirected to home

### Test 2: Resend After 30s
1. OTP Screen shows countdown (60 → 30)
2. Resend button becomes enabled at 30s
3. Click Resend
4. **Expected**: OTPResendService validates, Firebase sends new SMS, countdown resets to 60s, OTPResendStatus shows "2 of 3"

### Test 3: Rate Limit (Resend < 30s)
1. Click Resend button
2. Immediately click Resend again (< 30s later)
3. **Expected**: OTPResendException thrown, error SnackBar shown: "Please wait X seconds...", no Firebase call made

### Test 4: Max Resends (3x)
1. Resend after 30s → Attempt 1 of 3
2. Resend after 30s → Attempt 2 of 3
3. Resend after 30s → Attempt 3 of 3
4. Try resend again
5. **Expected**: OTPResendException thrown, error message: "Maximum resend attempts exceeded"

### Test 5: OTP Expiry (> 60s)
1. OTP Screen countdown reaches 0
2. Try to verify OTP
3. **Expected**: _otpExpired state is true, verification button shows "OTP expired. Request a new one."

### Test 6: Session Reset on Logout
1. User on OTP Screen, then navigates away
2. OTPResendService.clearOTPSession(phoneNumber) called
3. **Expected**: Firestore user doc: resend_at = null, resend_count = 0

---

## Error Handling

### OTPResendException Structure

```dart
class OTPResendException implements Exception {
  final String message;        // User-facing error message
  final String code;           // Machine-readable code
  final int? retryAfterSeconds; // How long to wait (if applicable)
}
```

### Exception Codes

| Code | Scenario | Example Message | User Action |
|------|----------|-----------------|------------|
| `rate_limited` | Resend < 30s ago | "Please wait 15 seconds before requesting another OTP" | Wait and retry |
| `max_resends_exceeded` | Resend count = 3 | "Maximum resend attempts exceeded. Please contact support." | Contact support |

### Firestore Field Validation

**Timestamp Operations** (all use DateTime.now()):
```dart
// Check interval
final resendAt = (resource.data.resend_at as Timestamp).toDate();
final interval = DateTime.now().difference(resendAt).inSeconds;
if (interval < 30) throw OTPResendException(...);

// Update timestamp
await firestore.collection('users').doc(phoneNumber).update({
  'resend_at': DateTime.now(),
});
```

---

## Security Considerations

1. **Firestore Rules**: Only allow Cloud Functions (backend) to update `resend_at`. Client apps can only trigger resend through AuthService.
2. **Timestamp Validation**: Always compare `DateTime.now()` on client to `Firestore Timestamp` (adjusted for clock skew if needed).
3. **Resend Token**: Store `resendToken` from previous SMS send to optimize Firebase Auth (reduces SMS generation on server).
4. **Phone Number Normalization**: Always convert to `+91XXXXXXXXXX` format before Firestore queries.
5. **Session Cleanup**: Call `clearOTPSession()` on logout to reset `resend_count` and `resend_at`.

---

## Firestore Schema Reference

**Collection**: `users`  
**Document ID**: Phone number (normalized, e.g., "9876543210")

```json
{
  "phone": "+919876543210",
  "role": "customer",
  "name": "John Doe",
  "email": "john@example.com",
  "createdAt": "2026-05-12T10:30:00Z",
  "updatedAt": "2026-05-12T10:35:00Z",
  
  // OTP Resend Throttling (NEW)
  "resend_at": "2026-05-12T10:35:42.123456Z",
  "resend_count": 2,
  "resend_at_formatted": "2026-05-12T10:35:42Z",
  
  // OTP Verification (NEW)
  "otp_verified_at": "2026-05-12T10:32:00Z",
  
  // Existing fields
  "fcm_token": "d1cV7...",
  "notifications_enabled": true
}
```

---

## Related Features

- **Feature 1**: Phone auth integration (initial OTP request)
- **Feature 2**: Payment retry (order-level rate limiting, similar pattern)
- **Feature 6**: Stock reservation (Firestore Transactions, similar validation pattern)
- **Firebase Security**: OTP expiry (handled by Firebase, UI just displays)

---

## Debugging Tips

### Issue: "OTP resend keeps failing with rate limit"
**Debug**:
1. Check Firestore user doc: is `resend_at` very recent (< 30s ago)?
2. Verify phone number format: should be "9876543210" (without +91)
3. Check `resend_count` value: if ≥ 3, need to logout/clear session

### Issue: "OTP countdown doesn't update"
**Debug**:
1. Verify `OTPCountdownTimer` is properly integrated in OTP screen build()
2. Check that `_otpExpired` state is wired to UI (disable verify button if true)

### Issue: "Firebase resend fails after successful OTP verify"
**Debug**:
1. Ensure `resetResendCounter()` is called in `verifyOTP()` **after** Firebase verify succeeds
2. Check that `_currentResendToken` is updated when new resendToken returned from Firebase

---

## Summary

Feature 7 transforms OTP from a silent, user-hostile experience into a professional security flow:

✅ **Real-time expiry feedback** (60s countdown with color warnings)  
✅ **Resend capability** (after 30s, prevents abuse)  
✅ **Rate limiting** (Firestore throttling + Firebase max attempts)  
✅ **Error clarity** (specific exception codes + user-friendly messages)  
✅ **Session management** (cleanup on logout, reset on success)

The implementation follows established patterns from Features 2 (payment retry) and 6 (stock reservation), ensuring consistency across the codebase.
