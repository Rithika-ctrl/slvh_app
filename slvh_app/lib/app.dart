import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/phone_input_screen.dart';
import 'features/auth/screens/home_screen.dart';

class SLVHApp extends StatelessWidget {
  const SLVHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SLVH Smart Shop',
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}

// Wrapper to check auth state on startup
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().getCurrentUser();
    
    // If user is logged in, show home. Otherwise, show phone input
    return user != null ? const HomeScreen() : const PhoneInputScreen();
  }
}

