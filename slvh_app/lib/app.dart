import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'features/cart/providers/cart_provider.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/session_manager_service.dart';
import 'core/utils/secure_logger.dart';
import 'connectivity/connectivity_provider.dart';     // ← Feature 11
import 'shared/widgets/no_internet_overlay.dart';    // ← Feature 11

class SLVHApp extends StatefulWidget {
  const SLVHApp({super.key});

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

  /// Initialize session management and auth state listening
  ///
  /// Feature 8: Firebase Token Refresh / Session Expiry
  ///
  /// This runs once at app startup to:
  /// 1. Create SessionManagerService (handles token refresh)
  /// 2. Create AuthService (handles auth operations)
  /// 3. Connect them to listen to Firebase auth state changes
  /// 4. Set up callbacks for session expiry/validity
  void _initializeSession() {
    _sessionManager = SessionManagerService();
    _authService = AuthService();

    AppLogger.debug('🚀 App: Initializing Firebase session management...');

    _sessionManager.initialize(
      onSessionExpired: () {
        AppLogger.debug('🔴 App: Session expired - user logged out');
      },
      onSessionValid: () {
        AppLogger.debug('✅ App: Session is valid');
      },
    );

    _authService.initializeSessionManager(_sessionManager);

    AppLogger.debug('✅ App: Firebase session initialized');
  }

  @override
  void dispose() {
    _sessionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Existing providers
        Provider<SessionManagerService>.value(value: _sessionManager),
        Provider<AuthService>.value(value: _authService),
        ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(),
        ),

        // ── Feature 11: Connectivity provider ───────────────────────────
        // ConnectivityProvider drives the NoInternetOverlay banner.
        // All screens that need to know they're offline can:
        //   context.watch<ConnectivityProvider>().isOnline
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (_) => ConnectivityProvider(),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'SLVH Smart Shop',
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.buildRouter(),
        // ── Feature 11: Wrap the router output with the overlay ──────────
        // builder intercepts every screen the router renders and wraps
        // it in NoInternetOverlay, so ALL screens automatically get the
        // animated offline banner — no per-screen changes needed.
        builder: (context, child) => NoInternetOverlay(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

