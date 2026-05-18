import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:slvh_app/features/payments/providers/payment_retry_provider.dart';
import 'package:slvh_app/features/payments/widgets/pending_retry_orders_dialog.dart';
import 'package:slvh_app/features/payments/screens/payment_screen.dart';

/// Mixin to add pending retry order checking to any stateful widget
/// Use this in your main app or home screen to automatically check for pending orders
mixin PendingRetryOrdersCheckerMixin<T extends StatefulWidget>
    on State<T> {
  bool _hasCheckedPendingOrders = false;

  /// Call this in initState() to check for pending orders
  Future<void> checkPendingRetryOrders() async {
    if (_hasCheckedPendingOrders) return;
    _hasCheckedPendingOrders = true;

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final phoneNumber = currentUser.phoneNumber ?? '';
    final recoveryService = PaymentRetryRecoveryService();

    try {
      final hasPending = await recoveryService.hasPendingRetries(phoneNumber);

      if (!hasPending || !mounted) return;

      // Get pending orders
      final pendingOrders =
          await recoveryService.getPendingRetryOrders(phoneNumber);

      if (pendingOrders.isEmpty || !mounted) return;

      // Show dialog
      await showPendingRetryOrdersDialog(
        context,
        pendingOrders: pendingOrders,
        onRetry: () {
          final oldestOrder = pendingOrders.last;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentScreen(
                orderId: oldestOrder.id,
                amount: oldestOrder.total,
                customerPhone: phoneNumber,
                orderModel: oldestOrder,
              ),
            ),
          );
        },
      );
    } catch (e) {
      AppLogger.debug('Error checking pending retry orders: $e');
      // Silently fail - don't disrupt user experience
    }
  }
}

/// Integration example for main app:
///
/// ```dart
/// class MyHomeScreen extends StatefulWidget {
///   @override
///   State<MyHomeScreen> createState() => _MyHomeScreenState();
/// }
///
/// class _MyHomeScreenState extends State<MyHomeScreen>
///     with PendingRetryOrdersCheckerMixin {
///   @override
///   void initState() {
///     super.initState();
///     checkPendingRetryOrders();  // Add this line
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       // ... rest of your UI
///     );
///   }
/// }
/// ```

/// Alternative: As a separate initialization method
class PendingRetryOrdersInitializer {
  /// Initialize pending retry orders check
  /// Call this in your app's main() or app initialization
  static Future<void> initialize(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final phoneNumber = currentUser.phoneNumber ?? '';
    final recoveryService = PaymentRetryRecoveryService();

    try {
      final hasPending = await recoveryService.hasPendingRetries(phoneNumber);
      if (!hasPending) return;

      final pendingOrders =
          await recoveryService.getPendingRetryOrders(phoneNumber);
      if (pendingOrders.isEmpty) return;

      if (!context.mounted) return;

      await showPendingRetryOrdersDialog(
        context,
        pendingOrders: pendingOrders,
        onRetry: () {
          final oldestOrder = pendingOrders.last;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentScreen(
                orderId: oldestOrder.id,
                amount: oldestOrder.total,
                customerPhone: phoneNumber,
                orderModel: oldestOrder,
              ),
            ),
          );
        },
      );
    } catch (e) {
      AppLogger.debug('Error initializing pending retry check: $e');
    }
  }
}

/// Usage in main app initialization:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   // ... Firebase initialization
///   runApp(const MyApp());
/// }
///
/// class MyApp extends StatefulWidget {
///   @override
///   State<MyApp> createState() => _MyAppState();
/// }
///
/// class _MyAppState extends State<MyApp> {
///   @override
///   void initState() {
///     super.initState();
///     WidgetsBinding.instance.addPostFrameCallback((_) {
///       PendingRetryOrdersInitializer.initialize(context);
///     });
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       // ... your app config
///     );
///   }
/// }
/// ```

