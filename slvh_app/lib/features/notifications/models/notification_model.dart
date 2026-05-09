/// Model for push notifications
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String? orderId;
  final String? orderStatus; // e.g., "Confirmed", "Ready for Pickup"
  final bool isRead;
  final DateTime createdAt;
  final String? actionUrl; // Route to navigate to on tap

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.orderId,
    this.orderStatus,
    this.isRead = false,
    required this.createdAt,
    this.actionUrl,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'orderId': orderId,
      'orderStatus': orderStatus,
      'isRead': isRead,
      'createdAt': createdAt,
      'actionUrl': actionUrl,
    };
  }

  /// Create from Firestore document
  factory NotificationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return NotificationModel(
      id: id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      body: data['body'] as String,
      orderId: data['orderId'] as String?,
      orderStatus: data['orderStatus'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      actionUrl: data['actionUrl'] as String?,
    );
  }

  /// Create a copy with modified fields
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? orderId,
    String? orderStatus,
    bool? isRead,
    DateTime? createdAt,
    String? actionUrl,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      orderId: orderId ?? this.orderId,
      orderStatus: orderStatus ?? this.orderStatus,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }
}

/// Notification types
enum NotificationType {
  orderConfirmed,
  orderPreparing,
  orderReady,
  orderCompleted,
  orderCancelled,
  paymentVerified,
  paymentRejected,
  general,
}

/// Extension to map notification type to message
extension NotificationTypeExtension on NotificationType {
  String get title {
    switch (this) {
      case NotificationType.orderConfirmed:
        return '✅ Order Confirmed';
      case NotificationType.orderPreparing:
        return '🍳 Preparing Your Order';
      case NotificationType.orderReady:
        return '📦 Ready for Pickup!';
      case NotificationType.orderCompleted:
        return '✓ Order Completed';
      case NotificationType.orderCancelled:
        return '❌ Order Cancelled';
      case NotificationType.paymentVerified:
        return '💰 Payment Verified';
      case NotificationType.paymentRejected:
        return '⚠️ Payment Rejected';
      case NotificationType.general:
        return 'Notification';
    }
  }

  String get body {
    switch (this) {
      case NotificationType.orderConfirmed:
        return 'Your payment has been verified. Order is confirmed!';
      case NotificationType.orderPreparing:
        return 'We are preparing your order now.';
      case NotificationType.orderReady:
        return 'Your order is ready! Come pick it up.';
      case NotificationType.orderCompleted:
        return 'Thank you for your order!';
      case NotificationType.orderCancelled:
        return 'Your order has been cancelled.';
      case NotificationType.paymentVerified:
        return 'Your payment has been verified successfully.';
      case NotificationType.paymentRejected:
        return 'Your payment could not be verified. Please try again.';
      case NotificationType.general:
        return 'You have a new notification.';
    }
  }

  String get orderId {
    switch (this) {
      case NotificationType.orderConfirmed:
      case NotificationType.orderPreparing:
      case NotificationType.orderReady:
      case NotificationType.orderCompleted:
      case NotificationType.orderCancelled:
        return 'order_status_changed';
      case NotificationType.paymentVerified:
      case NotificationType.paymentRejected:
        return 'payment_status_changed';
      case NotificationType.general:
        return 'general';
    }
  }
}
