import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

class SLVHApp extends StatelessWidget {
  const SLVHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SLVH Smart Shop',
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.buildRouter(),
    );
  }
}