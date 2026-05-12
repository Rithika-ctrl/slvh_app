import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';
import 'package:slvh_app/features/payments/services/payment_retry_service.dart';

/// Provider to check and manage pending retry orders
/// Used on app startup to notify users about orders requiring retry
final pendingRetryOrdersProvider =
    StreamProvider.family<List<OrderModel>, String>(
  (ref, customerId) {
    final retryService = PaymentRetryService();
    return retryService.watchPendingRetryOrders(customerId);
  },
);

/// Provider to get current user's pending retry orders
final currentUserPendingRetryOrdersProvider = StreamProvider<List<OrderModel>>(
  (ref) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    final phoneNumber = currentUser.phoneNumber ?? '';
    final retryService = PaymentRetryService();
    return retryService.watchPendingRetryOrders(phoneNumber);
  },
);

/// Service class for managing payment retry recovery
class PaymentRetryRecoveryService {
  final PaymentRetryService _retryService = PaymentRetryService();

  /// Check if user has any pending retry orders
  Future<bool> hasPendingRetries(String customerId) async {
    final pendingOrders =
        await _retryService.getPendingRetryOrders(customerId);
    return pendingOrders.isNotEmpty;
  }

  /// Get count of pending retry orders
  Future<int> getPendingRetryCount(String customerId) async {
    final pendingOrders =
        await _retryService.getPendingRetryOrders(customerId);
    return pendingOrders.length;
  }

  /// Get the oldest pending retry order (first to retry)
  Future<OrderModel?> getOldestPendingRetry(String customerId) async {
    final pendingOrders =
        await _retryService.getPendingRetryOrders(customerId);
    if (pendingOrders.isEmpty) return null;
    return pendingOrders.last; // Orders are sorted by createdAt descending
  }

  /// Get all pending retry orders sorted by created date (newest first)
  Future<List<OrderModel>> getPendingRetryOrders(String customerId) async {
    return await _retryService.getPendingRetryOrders(customerId);
  }
}
