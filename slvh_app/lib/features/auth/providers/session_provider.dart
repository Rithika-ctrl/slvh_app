import 'package:riverpod/riverpod.dart';
import 'package:slvh_app/features/auth/services/session_manager_service.dart';
import 'package:slvh_app/features/auth/services/auth_service.dart';

/// Session Manager Provider
/// 
/// Provides access to SessionManagerService for token refresh and auth state tracking
/// 
/// Usage:
/// ```dart
/// // Get session manager
/// final sessionManager = ref.watch(sessionManagerProvider);
/// 
/// // Get current auth state as stream
/// final authState = ref.watch(authStateStreamProvider);
/// 
/// // Check if session is valid
/// final isValid = await ref.watch(sessionValidityProvider.future);
/// ```

/// Provider for SessionManagerService singleton
final sessionManagerProvider = Provider<SessionManagerService>((ref) {
  throw UnimplementedError(
    'SessionManagerService must be provided from app root (SLVHApp)',
  );
});

/// Provider for AuthService singleton
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError(
    'AuthService must be provided from app root (SLVHApp)',
  );
});

/// Stream provider for auth state changes
/// 
/// Listen to Firebase auth state changes in real-time:
/// ```dart
/// final authState = ref.watch(authStateStreamProvider);
/// authState.when(
///   data: (state) {
///     // Handle auth state
///     if (state == AuthState.authenticated) {
///       // User logged in
///     }
///   },
///   loading: () => const CircularProgressIndicator(),
///   error: (err, st) => Text('Error: $err'),
/// );
/// ```
final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  final sessionManager = ref.watch(sessionManagerProvider);
  return sessionManager.authStateStream;
});

/// Future provider for session validity check
/// 
/// Check if current session is valid (user authenticated, token fresh):
/// ```dart
/// final isValid = ref.watch(sessionValidityProvider);
/// isValid.when(
///   data: (valid) => valid ? showHome() : showLogin(),
///   loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
///   error: (err, st) => showLogin(),
/// );
/// ```
final sessionValidityProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return authService.isSessionValid();
});

/// Future provider for getting a fresh token
/// 
/// Get a fresh Firebase ID token before Firestore operations:
/// ```dart
/// try {
///   final token = await ref.read(getRefreshedTokenProvider.future);
///   // Token is fresh, safe for Firestore ops
/// } on FirebaseAuthException {
///   // User logged out, redirect to login
/// }
/// ```
final getRefreshedTokenProvider = FutureProvider<String>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return authService.getRefreshedToken();
});

/// Stream provider for token refresh events
/// 
/// Monitor token refresh attempts:
/// ```dart
/// final refreshEvents = ref.watch(tokenRefreshEventsProvider);
/// refreshEvents.when(
///   data: (event) {
///     if (event == TokenRefreshEvent.success) {
///       // Token refreshed successfully
///     } else {
///       // Token refresh failed
///     }
///   },
///   loading: () => SizedBox.shrink(),
///   error: (err, st) => SizedBox.shrink(),
/// );
/// ```
final tokenRefreshEventsProvider = StreamProvider<TokenRefreshEvent>((ref) {
  final sessionManager = ref.watch(sessionManagerProvider);
  return sessionManager.tokenRefreshStream;
});
