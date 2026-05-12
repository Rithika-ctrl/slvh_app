# Feature 8: Firebase Token Refresh / Session Expiry Guide

## Problem Statement

### The Issue: Silent API Failures After 1 Hour

Firebase ID tokens expire after **exactly 1 hour** of being issued. Without proactive token refresh:

1. **Silent Failures**: Firestore writes fail silently without error messages
2. **User Experience**: User is logged in but operations mysteriously fail after 1 hour
3. **No Error Feedback**: App doesn't alert user that session has expired
4. **Inconsistent State**: Token valid locally but rejected by Firebase backend

### Real-World Scenario

```
Time 0:00 - User logs in → Firebase issues ID token (valid until 1:00)
Time 0:50 - User adds item to cart → Works (token still valid)
Time 1:05 - User tries to checkout → 🔴 FAILS SILENTLY
         - Token expired 5 minutes ago
         - No error shown to user
         - Firestore rejects write request
         - User thinks app is broken
```

---

## Solution Architecture

### Components

**SessionManagerService** (NEW - Feature 8):
- Listens to `FirebaseAuth.authStateChanges()` stream
- Auto-refreshes token on auth state changes
- Provides `getValidToken()` for explicit refresh before Firestore ops
- Tracks token refresh timestamp to avoid unnecessary API calls
- Handles InvalidCredentialException for expired sessions

**AuthService** (ENHANCED - Feature 8):
- Added `getRefreshedToken()` method
- Delegates to SessionManagerService for token refresh
- New `isSessionValid()` check
- New `authStateStream` for listening to auth changes

**SLVHApp** (UPDATED - Feature 8):
- Now StatefulWidget instead of StatelessWidget
- Initializes SessionManagerService on startup
- Provides both services to entire app via Provider
- Sets up callbacks for session expiry/validity

**Session Providers** (NEW - Feature 8):
- Riverpod providers for reactive session state
- `authStateStreamProvider`: Listen to auth changes
- `sessionValidityProvider`: Check if session is valid
- `getRefreshedTokenProvider`: Get fresh token before Firestore ops
- `tokenRefreshEventsProvider`: Monitor refresh attempts

### Token Refresh Flow

```
┌─────────────────────────────────────────────────────────────┐
│ App Startup                                                 │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ SLVHApp.initState()                                         │
│ - Create SessionManagerService                              │
│ - Create AuthService                                        │
│ - Call authService.initializeSessionManager()               │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ SessionManagerService.initialize()                          │
│ - Listen to FirebaseAuth.authStateChanges()                 │
│ - On user login: token auto-refreshed by Firebase          │
│ - On user logout: close streams, notify app                │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Before Firestore Write                                      │
│ (checkout, place order, add to cart, etc.)                 │
│                                                             │
│ Code pattern:                                               │
│   try {                                                     │
│     token = await authService.getRefreshedToken();          │
│     await firestore.collection('orders').add(...);          │
│   } on FirebaseAuthException {                              │
│     → User logged out, redirect to login                   │
│   }                                                         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Token Refresh Logic (SessionManagerService)                │
│                                                             │
│ 1. Check if user authenticated                             │
│ 2. Check if last refresh > 50 minutes ago                  │
│ 3. If yes: Call user.getIdToken(true) - FORCE REFRESH     │
│ 4. Record timestamp: _lastTokenRefresh = now()             │
│ 5. Return fresh token to caller                            │
│                                                             │
│ Cooldown: 50 min (before 60 min expiry)                    │
│ Avoids: Excessive Firebase API calls                       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
         ✅ Firestore Operation Succeeds
            (with fresh token)
```

### Token Expiry Handling

```
Scenario 1: User has valid session
┌──────────────────────────────────────────────┐
│ User logs in at 12:00 PM                    │
│ Token issued: 12:00 - 1:00 PM              │
│ Token stored in Firebase client              │
└──────────────────────────────────────────────┘
         │
         ├─→ [12:00-12:50] Operations work
         │   Token is fresh
         │
         ├─→ [12:50] Before checkout
         │   getRefreshedToken() called
         │   user.getIdToken(true) → Firebase validates
         │   Firebase issues NEW token (12:50 - 1:50 PM)
         │   ✅ Checkout succeeds
         │
         └─→ [12:55+] More operations
             Token fresh (just refreshed)
             ✅ Continue to work

Scenario 2: Session expires (user logged out elsewhere)
┌──────────────────────────────────────────────┐
│ Firebase detects user logout                 │
│ (e.g., password changed, admin revoked)      │
└──────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────┐
│ getRefreshedToken() called                   │
│ ↓                                            │
│ user.getIdToken(true)                        │
│ ↓                                            │
│ FirebaseAuthException('user-disabled')       │
│ or ('invalid-user-token')                    │
└──────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────┐
│ SessionManagerService catches exception      │
│ → AuthState.expired                          │
│ → Calls onSessionExpired callback            │
│ → _authStateController.add(AuthState.expired)│
└──────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────┐
│ App receives callback                        │
│ → Show snackbar: "Session expired"          │
│ → Redirect to login screen                  │
└──────────────────────────────────────────────┘
```

---

## File Structure

### New Files (2)

#### `lib/features/auth/services/session_manager_service.dart` (180 lines)

**Purpose**: Handle all token refresh and auth state management

**Key Classes**:
```dart
class SessionManagerService {
  // Listen to auth state changes
  Stream<AuthState> get authStateStream
  
  // Get fresh token before Firestore operations
  Future<String?> getValidToken()
  
  // Check if session is valid
  Future<bool> isSessionValid()
  
  // Initialize with callbacks
  void initialize({
    VoidCallback? onSessionExpired,
    VoidCallback? onSessionValid,
  })
  
  // Cleanup on app shutdown
  void dispose()
}

enum AuthState {
  authenticated,   // User logged in
  unauthenticated, // User logged out
  expired,         // Session expired
}

enum TokenRefreshEvent {
  success,  // Token refreshed
  failure,  // Refresh failed
}
```

**Key Methods**:
1. `initialize()` - Called once from app root, sets up auth state listener
2. `getValidToken()` - Call before EVERY Firestore write
3. `isSessionValid()` - Check if user has valid session
4. `dispose()` - Cleanup on app shutdown

**Token Refresh Logic**:
- Checks if user authenticated
- Checks if last refresh > 50 minutes ago
- Calls `user.getIdToken(true)` if needed
- Returns fresh token or throws FirebaseAuthException

#### `lib/features/auth/providers/session_provider.dart` (90 lines)

**Purpose**: Riverpod providers for reactive session state

**Providers**:
```dart
sessionManagerProvider          // Access SessionManagerService
authServiceProvider             // Access AuthService
authStateStreamProvider         // Watch auth state changes
sessionValidityProvider         // Watch if session is valid
getRefreshedTokenProvider       // Get fresh token
tokenRefreshEventsProvider      // Watch refresh events
```

**Usage Examples**:
```dart
// In widget/provider
final sessionManager = ref.watch(sessionManagerProvider);
final authState = ref.watch(authStateStreamProvider);
final isValid = ref.watch(sessionValidityProvider);
final token = await ref.read(getRefreshedTokenProvider.future);
```

### Modified Files (2)

#### `lib/features/auth/services/auth_service.dart`

**New Import**:
```dart
import 'package:slvh_app/features/auth/services/session_manager_service.dart';
```

**New Field**:
```dart
SessionManagerService? _sessionManager;
```

**New Methods**:
```dart
/// Initialize session manager
void initializeSessionManager(
  SessionManagerService sessionManager,
  {VoidCallback? onSessionExpired, VoidCallback? onSessionValid}
)

/// Get fresh token before Firestore operations
Future<String> getRefreshedToken()

/// Check if session is valid
Future<bool> isSessionValid()

/// Get auth state stream
Stream<AuthState> get authStateStream
```

#### `lib/app.dart`

**Changed from StatelessWidget to StatefulWidget**:
```dart
class SLVHApp extends StatefulWidget {
  @override
  State<SLVHApp> createState() => _SLVHAppState();
}

class _SLVHAppState extends State<SLVHApp> {
  late SessionManagerService _sessionManager;
  late AuthService _authService;
  
  @override
  void initState() {
    super.initState();
    _initializeSession();
  }
  
  void _initializeSession() {
    _sessionManager = SessionManagerService();
    _authService = AuthService();
    _sessionManager.initialize(...);
    _authService.initializeSessionManager(_sessionManager);
  }
  
  @override
  void dispose() {
    _sessionManager.dispose();
    super.dispose();
  }
}
```

**Provides Both Services**:
```dart
MultiProvider(
  providers: [
    Provider<SessionManagerService>.value(value: _sessionManager),
    Provider<AuthService>.value(value: _authService),
    ChangeNotifierProvider<CartProvider>(...),
  ],
  child: MaterialApp.router(...),
)
```

---

## Usage Patterns

### Pattern 1: Before Firestore Write (Required)

```dart
// Example: Place order
Future<void> placeOrder(OrderModel order) async {
  try {
    // 🔴 CRITICAL: Refresh token before write
    final token = await _authService.getRefreshedToken();
    
    // Now token is fresh, safe for Firestore
    await _firestore
        .collection('orders')
        .doc(orderId)
        .set(order.toMap());
    
    print('✅ Order created successfully');
  } on FirebaseAuthException catch (e) {
    // Token refresh failed, user likely logged out
    print('❌ Session expired: ${e.message}');
    // Redirect to login
    context.go('/');
  } catch (e) {
    print('❌ Order creation failed: $e');
    // Handle other errors
  }
}
```

### Pattern 2: Monitor Auth State Changes

```dart
// In widget build method
final authState = ref.watch(authStateStreamProvider);

return authState.when(
  data: (state) {
    switch (state) {
      case AuthState.authenticated:
        return HomeScreen(); // User logged in
      case AuthState.unauthenticated:
        return LoginScreen(); // User logged out
      case AuthState.expired:
        return SessionExpiredScreen(); // Token expired
    }
  },
  loading: () => const LoadingScreen(),
  error: (err, st) => ErrorScreen(error: err),
);
```

### Pattern 3: Check Session Validity

```dart
// Before critical operation
final isValid = await authService.isSessionValid();

if (!isValid) {
  // Session invalid, redirect to login
  context.go('/');
  return;
}

// Session valid, proceed with operation
await placeOrder(order);
```

### Pattern 4: Listen to Token Refresh Events

```dart
final refreshEvents = ref.watch(tokenRefreshEventsProvider);

return refreshEvents.when(
  data: (event) {
    if (event == TokenRefreshEvent.success) {
      showSnackBar('Session refreshed');
    } else {
      showSnackBar('Failed to refresh session');
    }
    return SizedBox.shrink();
  },
  loading: () => SizedBox.shrink(),
  error: (err, st) => SizedBox.shrink(),
);
```

---

## Implementation Checklist

### ✅ Completed

- [x] Created SessionManagerService with auth state listening
- [x] Created session_provider.dart with Riverpod integration
- [x] Updated AuthService with token refresh methods
- [x] Updated SLVHApp to initialize SessionManagerService
- [x] Added callbacks for session expiry/validity
- [x] Token refresh logic with 50-minute cooldown (before 60-min expiry)

### 🔲 Recommended Next Steps

1. **Update Firestore Write Operations**
   - Add `getRefreshedToken()` call before critical writes:
     - Place order in checkout_service.dart
     - Update cart in cart_service.dart
     - Update inventory in stock_service.dart
     - Create refund in refund_service.dart

2. **Error Handling**
   - Add try-catch in services to handle FirebaseAuthException
   - Show user-friendly error messages
   - Redirect to login on session expiry

3. **UI Indicators** (Optional)
   - Show token refresh status in AppBar
   - Display session countdown timer
   - Warning message when token about to expire

4. **Testing**
   - Test token refresh after 50 minutes of inactivity
   - Test behavior when token expires
   - Test session recovery after network interruption

---

## Firestore Write Operations to Update

The following files should be updated to use `getRefreshedToken()` before Firestore writes:

### High Priority (Cart/Checkout/Orders)

```dart
// lib/features/cart/services/cart_service.dart
Future<void> addToCart(String itemId, int quantity) async {
  final token = await _authService.getRefreshedToken(); // NEW
  await _firestore.collection('cart').doc(itemId).set(...);
}

// lib/features/checkout/services/checkout_service.dart
Future<OrderModel> placeOrder(OrderModel order) async {
  final token = await _authService.getRefreshedToken(); // NEW
  await _firestore.collection('orders').doc(orderId).set(...);
}

// lib/features/orders/services/order_service.dart
Future<void> cancelOrder(String orderId) async {
  final token = await _authService.getRefreshedToken(); // NEW
  await _firestore.collection('orders').doc(orderId).update(...);
}
```

### Medium Priority (Inventory/Stock)

```dart
// lib/features/inventory/services/stock_service.dart
Future<void> reserveStock(String productId, int quantity) async {
  final token = await _authService.getRefreshedToken(); // NEW
  await _firestore.runTransaction((transaction) { ... });
}
```

### Low Priority (Notifications/Analytics)

```dart
// lib/features/notifications/services/notification_service.dart
Future<void> saveFCMTokenForUser(String phoneNumber) async {
  final token = await _authService.getRefreshedToken(); // NEW
  await _firestore.collection('users').doc(phoneNumber).update(...);
}
```

---

## Error Scenarios & Recovery

### Scenario 1: Token Expired After 1 Hour

```
User logged in at 12:00 PM
↓ (60 minutes pass)
User tries to place order at 1:05 PM
↓
getRefreshedToken() called
↓
user.getIdToken(true) fails
↓
FirebaseAuthException('invalid-user-token')
↓
SessionManager → AuthState.expired
↓
App shows: "Session expired. Please log in again."
↓
User redirected to login screen
```

### Scenario 2: User Logged Out By Admin

```
User logged in as customer
↓
Admin revokes user access via Firebase Console
↓
User tries to perform any Firestore operation
↓
getRefreshedToken() called
↓
user.getIdToken(true) fails
↓
FirebaseAuthException('user-disabled')
↓
SessionManager catches, calls onSessionExpired()
↓
App redirects to login with message: "Your account has been disabled"
```

### Scenario 3: Password Changed (Firebase Email Auth)

```
User logged in as admin
↓
User changes password in another device
↓
Current device's token becomes invalid
↓
Next API call: getRefreshedToken()
↓
user.getIdToken(true) fails
↓
App detects session expired
↓
Admin logged out, redirected to login
```

### Scenario 4: Network Timeout During Token Refresh

```
User has valid session but network is slow
↓
getRefreshedToken() called
↓
HTTP timeout waiting for Firebase response
↓
Exception: TimeoutException
↓
SessionManager logs error, but doesn't change auth state
↓
Retry mechanism: App can retry after delay
↓
If persistent: May degrade to cached token (risky)
```

---

## Performance Considerations

### Token Refresh Cooldown

**Why 50 minutes?**
- Firebase tokens expire after 60 minutes
- Refreshing at 50 minutes ensures 10-minute buffer
- Avoids expired token reaching backend
- Reduces unnecessary Firebase API calls

**Refresh Frequency**:
- Every operation: Maximum safety, slightly higher API cost
- Every 50 min: Optimized, 1-2 refreshes per hour per user
- Smart refresh: Only when necessary (current implementation)

### Firebase Cost Impact

```
Without token refresh:
- All Firestore writes after 1 hour fail silently
- App appears broken
- Users frustrated, app ratings drop

With token refresh (current):
- ~2 token refreshes per active user per hour
- Very low Firebase Auth API cost
- One additional getIdToken() call per critical operation
- Cost: Negligible (Firebase Auth is free for most projects)
```

---

## Summary

Feature 8 solves the critical problem of **silent API failures after 1 hour of login** by:

✅ **Real-time Auth State Listening** - Firebase authStateChanges() stream  
✅ **Proactive Token Refresh** - getIdToken(true) before Firestore writes  
✅ **Session Validity Tracking** - Timestamp-based cooldown (50 min)  
✅ **Error Recovery** - Detect expired sessions, redirect to login  
✅ **Riverpod Integration** - Reactive state management throughout app  
✅ **Developer-Friendly API** - Simple `getRefreshedToken()` pattern  

**Key Code Pattern**:
```dart
try {
  await authService.getRefreshedToken(); // Refresh token
  await firestore.write(...); // Safe Firestore operation
} on FirebaseAuthException {
  // User logged out, redirect to login
}
```

This ensures **every Firestore write** has a fresh, valid token, preventing silent failures and providing a professional user experience.
