import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'features/cart/providers/cart_provider.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/session_manager_service.dart';

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

    print('🚀 App: Initializing Firebase session management...');

    // Initialize session manager with callbacks
    _sessionManager.initialize(
      onSessionExpired: () {
        print('🔴 App: Session expired - user logged out');
        // Optionally show snackbar or redirect to login
      },
      onSessionValid: () {
        print('✅ App: Session is valid');
      },
    );

    // Connect AuthService to SessionManagerService
    _authService.initializeSessionManager(_sessionManager);

    print('✅ App: Firebase session initialized');
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
        // Provide services to the app
        Provider<SessionManagerService>.value(value: _sessionManager),
        Provider<AuthService>.value(value: _authService),
        
        // Cart provider
        ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'SLVH Smart Shop',
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.buildRouter(),
      ),
    );
  }
}