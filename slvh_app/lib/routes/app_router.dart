import 'package:flutter/material.dart';
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

class AppRouter {
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

