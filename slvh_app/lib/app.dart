import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/phone_input_screen.dart';
import 'features/auth/screens/home_screen.dart';
import 'features/auth/screens/admin_dashboard.dart';

class SLVHApp extends StatelessWidget {
  const SLVHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SLVH Smart Shop',
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<Map<String, bool>> _loginStatusFuture;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loginStatusFuture = _checkLoginStatus();
  }

  Future<Map<String, bool>> _checkLoginStatus() async {
    final isCustomerLoggedIn = await _authService.isUserLoggedIn();
    final isAdminLoggedIn = await _authService.isAdminLoggedIn();
    return {
      'customer': isCustomerLoggedIn,
      'admin': isAdminLoggedIn,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, bool>>(
      future: _loginStatusFuture,
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

        final loginStatus = snapshot.data ?? {'customer': false, 'admin': false};
        final isCustomerLoggedIn = loginStatus['customer'] ?? false;
        final isAdminLoggedIn = loginStatus['admin'] ?? false;

        // Priority: Check admin first, then customer
        if (isAdminLoggedIn) {
          return const AdminDashboard();
        } else if (isCustomerLoggedIn) {
          return const HomeScreen();
        } else {
          return const PhoneInputScreen();
        }
      },
    );
  }
}