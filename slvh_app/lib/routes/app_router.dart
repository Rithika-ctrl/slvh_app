import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/services/auth_service.dart';
import '../features/auth/screens/phone_input_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/screens/home_screen.dart';
import '../features/auth/screens/admin_login_screen.dart';
import '../features/auth/screens/admin_dashboard.dart';

class AppRoutes {
  static const String phoneInput = '/';
  static const String otp        = '/otp';
  static const String home       = '/home';
  static const String adminLogin = '/admin-login';
  static const String adminHome  = '/admin';
}

/// GoRouter configuration with route guards and role-based access control
class AppRouter {
  static final AuthService _authService = AuthService();

  /// Build the router with route guards
  static GoRouter buildRouter() {
    return GoRouter(
      initialLocation: AppRoutes.phoneInput,
      redirect: (context, state) async {
        // Get current auth state
        final isCustomerLoggedIn = await _authService.isUserLoggedIn();
        final isAdminLoggedIn = await _authService.isAdminLoggedIn();
        final role = await _authService.getCurrentUserRole();

        // If not authenticated and trying to access protected routes
        if (!isCustomerLoggedIn && !isAdminLoggedIn) {
          // Allow access to public routes
          if (state.matchedLocation == AppRoutes.phoneInput ||
              state.matchedLocation == AppRoutes.otp ||
              state.matchedLocation == AppRoutes.adminLogin) {
            return null; // Allow navigation
          }
          // Redirect to login
          return AppRoutes.phoneInput;
        }

        // ========== ROUTE GUARDS & ROLE-BASED ACCESS CONTROL ==========

        // Admin Routes Protection
        if (state.matchedLocation == AppRoutes.adminHome) {
          // Only allow admins to access admin dashboard
          if (isAdminLoggedIn && role == 'admin') {
            return null; // Allow access
          }
          // Non-admins trying to access admin page → redirect to customer home
          if (isCustomerLoggedIn) {
            return AppRoutes.home;
          }
          // Not authenticated → redirect to login
          return AppRoutes.phoneInput;
        }

        // Customer Routes Protection
        if (state.matchedLocation == AppRoutes.home) {
          // Only allow customers to access customer home
          if (isCustomerLoggedIn && role != 'admin') {
            return null; // Allow access
          }
          // Admins trying to access customer home → redirect to admin dashboard
          if (isAdminLoggedIn) {
            return AppRoutes.adminHome;
          }
          // Not authenticated → redirect to login
          return AppRoutes.phoneInput;
        }

        // Admin login should only be accessible if not logged in as admin
        if (state.matchedLocation == AppRoutes.adminLogin) {
          if (isAdminLoggedIn) {
            return AppRoutes.adminHome; // Already logged in as admin
          }
          return null; // Allow access to admin login
        }

        return null;
      },
      routes: [
        // ========== PUBLIC ROUTES ==========

        GoRoute(
          path: AppRoutes.phoneInput,
          name: 'phoneInput',
          builder: (context, state) => const PhoneInputScreen(),
        ),

        GoRoute(
          path: AppRoutes.otp,
          name: 'otp',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final phoneNumber = extra?['phoneNumber'] as String? ?? '';
            final verificationId = extra?['verificationId'] as String? ?? '';

            return OTPScreen(
              phoneNumber: phoneNumber,
              verificationId: verificationId,
            );
          },
        ),

        GoRoute(
          path: AppRoutes.adminLogin,
          name: 'adminLogin',
          builder: (context, state) => const AdminLoginScreen(),
        ),

        // ========== PROTECTED ROUTES ==========

        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),

        GoRoute(
          path: AppRoutes.adminHome,
          name: 'adminHome',
          builder: (context, state) => const AdminDashboard(),
        ),
      ],

      // Fallback for unknown routes
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Page not found',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.phoneInput),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== LEGACY ROUTE GENERATION (FOR BACKWARD COMPATIBILITY) ==========
  // This can be removed once app.dart is fully migrated to go_router

  @deprecated
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.phoneInput:
        return MaterialPageRoute(
          builder: (_) => const PhoneInputScreen(),
        );

      case AppRoutes.otp:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => OTPScreen(
            phoneNumber: args['phoneNumber'] as String,
            verificationId: args['verificationId'] as String,
          ),
        );

      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );

      case AppRoutes.adminLogin:
        return MaterialPageRoute(
          builder: (_) => const AdminLoginScreen(),
        );

      case AppRoutes.adminHome:
        return MaterialPageRoute(
          builder: (_) => const AdminDashboard(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Page not found', style: TextStyle(color: Colors.white)),
            ),
          ),
        );
    }
  }
}

