import 'package:flutter/material.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/auth/screens/phone_input_screen.dart';
import '../../features/auth/screens/home_screen.dart';
import '../../features/auth/screens/admin_dashboard.dart';

/// AuthWrapper Widget
/// 
/// Handles the authentication routing logic using StreamBuilder.
/// Monitors real-time changes in login state and redirects users accordingly.
/// 
/// 1. If not logged in → PhoneInputScreen
/// 2. If admin logged in → AdminDashboard
/// 3. If customer logged in → HomeScreen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<Map<String, dynamic>> _authStateFuture;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _authStateFuture = _getInitialAuthState();
  }

  /// Get initial auth state on app startup
  Future<Map<String, dynamic>> _getInitialAuthState() async {
    try {
      final isCustomerLoggedIn = await _authService.isUserLoggedIn();
      final isAdminLoggedIn = await _authService.isAdminLoggedIn();
      final role = await _authService.getCurrentUserRole();

      return {
        'customerLoggedIn': isCustomerLoggedIn,
        'adminLoggedIn': isAdminLoggedIn,
        'role': role,
      };
    } catch (e) {
      print('Error getting initial auth state: $e');
      return {
        'customerLoggedIn': false,
        'adminLoggedIn': false,
        'role': null,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _authStateFuture,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error state - default to login
        if (snapshot.hasError) {
          return const PhoneInputScreen();
        }

        final authState = snapshot.data ?? {
          'customerLoggedIn': false,
          'adminLoggedIn': false,
          'role': null,
        };

        final isCustomerLoggedIn = authState['customerLoggedIn'] as bool;
        final isAdminLoggedIn = authState['adminLoggedIn'] as bool;
        final role = authState['role'] as String?;

        // ========== ROUTE GUARDS & ROLE-BASED ACCESS ==========
        
        // Priority 1: Check admin access
        if (isAdminLoggedIn && role == 'admin') {
          return const AdminDashboard();
        }

        // Priority 2: Check customer access
        if (isCustomerLoggedIn && role != null) {
          return const HomeScreen();
        }

        // Priority 3: Default to login if no valid role
        return const PhoneInputScreen();
      },
    );
  }
}
