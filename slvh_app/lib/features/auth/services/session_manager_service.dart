import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
/// Session Management Service
///
/// Handles:
/// - Real-time auth state listening via authStateChanges()
/// - Proactive Firebase ID token refresh (expires after 1 hour)
/// - Session validity checks for Firestore operations
/// - Automatic logout on token expiry or auth state changes
///
/// Problem Solved:
/// Firebase ID tokens expire after 1 hour. Without refresh, subsequent
/// API calls (Firestore reads/writes) fail silently, breaking functionality.
///
/// Solution:
/// 1. Listen to auth state changes (Firebase auto-refreshes on state change)
/// 2. Before Firestore writes, call getIdToken(true) to force refresh
/// 3. Handle InvalidCredentialException if token is invalid → redirect to login
/// 4. Track token refresh timestamp to avoid unnecessary refreshes
class SessionManagerService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream controllers for session state
  final _authStateController = StreamController<AuthState>.broadcast();
  final _tokenRefreshController = StreamController<TokenRefreshEvent>.broadcast();

  // Token refresh tracking
  DateTime? _lastTokenRefresh;
  static const Duration _tokenRefreshCooldown = Duration(minutes: 50); // Refresh every 50 min (before 60 min expiry)

  // Subscription to auth state changes
  StreamSubscription<User?>? _authStateSubscription;

  // Callbacks
  VoidCallback? _onSessionExpired;
  VoidCallback? _onSessionValid;

  /// Expose auth state as stream
  Stream<AuthState> get authStateStream => _authStateController.stream;
  
  /// Expose token refresh events
  Stream<TokenRefreshEvent> get tokenRefreshStream => _tokenRefreshController.stream;

  /// Initialize session manager and listen to auth state changes
  void initialize({
    VoidCallback? onSessionExpired,
    VoidCallback? onSessionValid,
  }) {
    _onSessionExpired = onSessionExpired;
    _onSessionValid = onSessionValid;

    print('🔐 SessionManager: Initializing auth state listener');

    // Listen to Firebase auth state changes
    _authStateSubscription = _auth.authStateChanges().listen(
      (User? user) {
        if (user != null) {
          print('✅ SessionManager: User authenticated (${user.phoneNumber ?? user.email})');
          _authStateController.add(AuthState.authenticated);
          _onSessionValid?.call();
          
          // Refresh token on auth state change (Firebase auto-refresh)
          _refreshToken(forceRefresh: true);
        } else {
          print('❌ SessionManager: User logged out');
          _authStateController.add(AuthState.unauthenticated);
          _onSessionExpired?.call();
        }
      },
      onError: (error) {
        print('❌ SessionManager: Auth state error: $error');
        _authStateController.addError(error);
      },
    );
  }

  /// Get a fresh ID token before Firestore operations
  ///
  /// This method should be called before every Firestore write:
  /// ```dart
  /// final token = await sessionManager.getValidToken();
  /// if (token == null) {
  ///   // User logged out, redirect to login
  ///   return;
  /// }
  /// // Token is fresh, safe to use in Firestore operations
  /// ```
  ///
  /// Returns: Valid ID token string, or null if user is not authenticated
  /// Throws: FirebaseAuthException if token refresh fails
  Future<String?> getValidToken() async {
    final user = _auth.currentUser;
    
    if (user == null) {
      print('⚠️ SessionManager: No user authenticated');
      return null;
    }

    try {
      // Get a fresh token (force refresh if needed)
      final token = await user.getIdToken(true);
      print('✅ SessionManager: Token refreshed successfully');
      
      _lastTokenRefresh = DateTime.now();
      _tokenRefreshController.add(TokenRefreshEvent.success);
      
      return token;
    } on FirebaseAuthException catch (e) {
      print('❌ SessionManager: Token refresh failed (${e.code}): ${e.message}');
      
      // Handle specific auth exceptions
      if (e.code == 'user-disabled' || e.code == 'invalid-user-token') {
        print('🔴 SessionManager: User token invalid, session expired');
        _authStateController.add(AuthState.expired);
        _onSessionExpired?.call();
      }
      
      _tokenRefreshController.add(TokenRefreshEvent.failure);
      rethrow;
    } catch (e) {
      print('❌ SessionManager: Unexpected error during token refresh: $e');
      _tokenRefreshController.add(TokenRefreshEvent.failure);
      rethrow;
    }
  }

  /// Check if current session is valid
  ///
  /// Returns: true if user is authenticated and token is fresh
  Future<bool> isSessionValid() async {
    final user = _auth.currentUser;
    
    if (user == null) {
      print('⚠️ SessionManager: No user authenticated');
      return false;
    }

    // Check if token needs refresh (last refresh > 50 minutes ago)
    if (_lastTokenRefresh != null) {
      final timeSinceRefresh = DateTime.now().difference(_lastTokenRefresh!);
      if (timeSinceRefresh < _tokenRefreshCooldown) {
        return true; // Token is still fresh
      }
    }

    // Token is potentially stale, refresh it
    try {
      await getValidToken();
      return true;
    } catch (e) {
      print('❌ SessionManager: Session validation failed: $e');
      return false;
    }
  }

  /// Refresh token if cooldown has passed
  ///
  /// Internal method called periodically or on demand
  /// Avoids unnecessary Firebase calls within cooldown period
  Future<void> _refreshToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    
    if (user == null) return;

    // Check cooldown to avoid excessive refreshes
    if (!forceRefresh && _lastTokenRefresh != null) {
      final timeSinceRefresh = DateTime.now().difference(_lastTokenRefresh!);
      if (timeSinceRefresh < _tokenRefreshCooldown) {
        return; // Within cooldown, skip refresh
      }
    }

    try {
      print('🔄 SessionManager: Refreshing token...');
      await user.getIdToken(true);
      _lastTokenRefresh = DateTime.now();
      print('✅ SessionManager: Token refresh successful');
      _tokenRefreshController.add(TokenRefreshEvent.success);
    } catch (e) {
      print('❌ SessionManager: Token refresh error: $e');
      _tokenRefreshController.add(TokenRefreshEvent.failure);
    }
  }

  /// Get user's current ID token (without forcing refresh)
  ///
  /// Returns: Current token or null if user not authenticated
  /// Note: This returns cached token, may be stale. Use getValidToken() before Firestore ops.
  Future<String?> getCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    try {
      return await user.getIdToken(false); // false = don't force refresh
    } catch (e) {
      print('⚠️ SessionManager: Failed to get current token: $e');
      return null;
    }
  }

  /// Get current authenticated user
  User? getCurrentUser() => _auth.currentUser;

  /// Listen to auth state changes directly (alternative to stream)
  void addAuthStateListener(Function(User?) callback) {
    _authStateSubscription ??= _auth.authStateChanges().listen(callback);
  }

  /// Cleanup: dispose subscriptions and close streams
  void dispose() {
    print('🔐 SessionManager: Disposing resources');
    _authStateSubscription?.cancel();
    _authStateController.close();
    _tokenRefreshController.close();
  }
}

/// Auth state enum for cleaner state management
enum AuthState {
  authenticated,   // User logged in, token valid
  unauthenticated, // User logged out
  expired,         // Session expired (token invalid)
}

/// Token refresh event for tracking refresh attempts
enum TokenRefreshEvent {
  success,  // Token successfully refreshed
  failure,  // Token refresh failed
}
