import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/auth/services/auth_service.dart';
import '../features/auth/screens/phone_input_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/screens/home_screen.dart';
import '../features/auth/screens/admin_login_screen.dart';
import '../features/auth/screens/admin_dashboard.dart';
import '../features/orders/models/order_model.dart';
import '../features/orders/screens/order_summary_screen.dart';
import '../features/orders/screens/order_history_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/checkout/screens/checkout_screen.dart';

class AppRoutes {
  static const String phoneInput = '/';
  static const String otp        = '/otp';
  static const String home       = '/home';
  static const String adminLogin = '/admin-login';
  static const String adminHome  = '/admin';
  static const String checkout   = '/checkout';
  static const String orders     = '/orders';
  static const String notifications = '/notifications';
  static const String orderSummary = '/order-summary';
  static const String orderDetail = '/order';
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

        // Customer Routes Protection (home, checkout, orders, order details)
        if (state.matchedLocation == AppRoutes.home ||
            state.matchedLocation == AppRoutes.checkout ||
            state.matchedLocation == AppRoutes.orders ||
            state.matchedLocation == AppRoutes.orderSummary ||
            state.matchedLocation.startsWith('${AppRoutes.orderDetail}/')) {
          // Only allow customers to access customer routes
          if (isCustomerLoggedIn && role != 'admin') {
            return null; // Allow access
          }
          // Admins trying to access customer routes → redirect to admin dashboard
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

        // ========== CHECKOUT & ORDER ROUTES (Customer) ==========

        GoRoute(
          path: AppRoutes.checkout,
          name: 'checkout',
          builder: (context, state) {
            final cartSummary = state.extra as Map<String, dynamic>?;
            if (cartSummary == null) {
              return const Scaffold(
                body: Center(child: Text('Cart data not found')),
              );
            }
            return CheckoutScreen(cartSummary: cartSummary);
          },
        ),

        GoRoute(
          path: AppRoutes.orders,
          name: 'orders',
          builder: (context, state) {
            final phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
            return OrderHistoryScreen(
              customerId: phoneNumber,
              onOrderTap: (orderId) => context.push('${AppRoutes.orderDetail}/$orderId'),
            );
          },
        ),

        GoRoute(
          path: AppRoutes.notifications,
          name: 'notifications',
          builder: (context, state) {
            final phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
            return NotificationsScreen(userId: phoneNumber);
          },
        ),

        GoRoute(
          path: '${AppRoutes.orderDetail}/:orderId',
          name: 'orderDetail',
          builder: (context, state) {
            final orderId = state.pathParameters['orderId'] ?? '';
            return OrderDetailScreen(orderId: orderId);
          },
        ),

        GoRoute(
          path: AppRoutes.orderSummary,
          name: 'orderSummary',
          builder: (context, state) {
            final order = state.extra as OrderModel?;
            if (order == null) {
              return const Scaffold(
                body: Center(child: Text('Order data not found')),
              );
            }
            return OrderSummaryScreen(
              order: order,
              onContinueShopping: () => context.go(AppRoutes.home),
              onViewOrders: () => context.push(AppRoutes.orders),
            );
          },
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

