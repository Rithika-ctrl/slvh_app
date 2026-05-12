import 'package:cloud_firestore/cloud_firestore.dart';

/// Order status enum
enum OrderStatus {
  pendingPayment('Pending Payment'),
  paymentRetryPending('Payment Retry Pending'),
  paymentVerificationPending('Payment Verification Pending'),
  paymentRejected('Payment Rejected'),
  confirmed('Confirmed'),
  preparing('Preparing'),
  readyForPickup('Ready for Pickup'),
  completed('Completed'),
  cancelled('Cancelled');

  final String label;
  const OrderStatus(this.label);

  /// Get color for status badge
  /// Green: Ready, Blue: In Progress, Orange: Pending, Red: Error/Cancelled
  String getColorHex() {
    switch (this) {
      case OrderStatus.confirmed:
      case OrderStatus.readyForPickup:
      case OrderStatus.completed:
        return '4CAF50'; // Green
      case OrderStatus.preparing:
        return '2196F3'; // Blue
      case OrderStatus.pendingPayment:
      case OrderStatus.paymentRetryPending:
      case OrderStatus.paymentVerificationPending:
        return 'FF9800'; // Orange
      case OrderStatus.paymentRejected:
      case OrderStatus.cancelled:
        return 'F44336'; // Red
    }
  }

  /// Convert string to enum
  static OrderStatus fromString(String value) {
    return values.firstWhere(
      (status) => status.name == value,
      orElse: () => OrderStatus.pendingPayment,
    );
  }
}

/// Item in an order
class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice; // Price per unit
  final double totalPrice; // Total for this item
  final String? selectedTierUnit; // e.g., "1 KG", "Pack of 5"
  final double? discountPercent; // If tier was selected

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.selectedTierUnit,
    this.discountPercent,
  });

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'selectedTierUnit': selectedTierUnit,
      'discountPercent': discountPercent,
    };
  }

  /// Create from JSON
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      selectedTierUnit: json['selectedTierUnit'],
      discountPercent: (json['discountPercent'] as num?)?.toDouble(),
    );
  }
}

/// Order model
class OrderModel {
  final String id; // Order ID (document ID)
  final String customerId; // Customer phone number
  final List<OrderItem> items;
  final double subtotal; // Before tax
  final double tax; // Calculated tax (5%)
  final double total; // After tax
  final OrderStatus status;
  final String? paymentId; // Reference to payment document
  final String? paymentStatus; // Payment status (Pending, Verification Pending, Verified, Rejected)
  final String? paymentReference; // Transaction ID or reference for retry
  final int retryCount; // Number of payment/upload retry attempts
  final String pickupDate; // YYYY-MM-DD format
  final String pickupTime; // HH:MM format
  final String pickupSlotId; // Reference to slot
  final String? cancellationReason; // Reason if order was cancelled

  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastRetryAt; // Timestamp of last retry attempt
  final DateTime? cancelledAt; // When order was cancelled
  final DateTime? completedAt; // When order was completed

  OrderModel({
    required this.id,
    required this.customerId,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    this.status = OrderStatus.pendingPayment,
    this.paymentId,
    this.paymentStatus,
    this.paymentReference,
    this.retryCount = 0,
    required this.pickupDate,
    required this.pickupTime,
    required this.pickupSlotId,
    this.cancellationReason,
    required this.createdAt,
    this.updatedAt,
    this.lastRetryAt,
    this.cancelledAt,
    this.completedAt,
  });

  /// Check if order is active
  bool get isActive =>
      status != OrderStatus.completed && status != OrderStatus.cancelled;

  /// Check if payment is verified
  bool get isPaymentVerified => paymentStatus == 'Verified';

  /// Check if order is ready for pickup
  bool get isReadyForPickup => status == OrderStatus.readyForPickup;

  /// Get item count
  int get itemCount => items.length;

  /// Get total unit quantity
  int get totalQuantity =>
      items.fold(0, (sum, item) => sum + item.quantity);

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'status': status.name,
      'paymentId': paymentId,
      'paymentStatus': paymentStatus,
      'paymentReference': paymentReference,
      'retryCount': retryCount,
      'pickupDate': pickupDate,
      'pickupTime': pickupTime,
      'pickupSlotId': pickupSlotId,
      'cancellationReason': cancellationReason,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastRetryAt': lastRetryAt,
      'cancelledAt': cancelledAt,
      'completedAt': completedAt,
    };
  }

  /// Create from Firestore document
  factory OrderModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return OrderModel(
      id: id,
      customerId: data['customerId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (data['tax'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.fromString(data['status'] ?? 'pendingPayment'),
      paymentId: data['paymentId'],
      paymentStatus: data['paymentStatus'],
      paymentReference: data['paymentReference'],
      retryCount: (data['retryCount'] as num?)?.toInt() ?? 0,
      pickupDate: data['pickupDate'] ?? '',
      pickupTime: data['pickupTime'] ?? '',
      pickupSlotId: data['pickupSlotId'] ?? '',
      cancellationReason: data['cancellationReason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastRetryAt: (data['lastRetryAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create a copy with modifications
  OrderModel copyWith({
    String? id,
    String? customerId,
    List<OrderItem>? items,
    double? subtotal,
    double? tax,
    double? total,
    OrderStatus? status,
    String? paymentId,
    String? paymentStatus,
    String? paymentReference,
    int? retryCount,
    String? pickupDate,
    String? pickupTime,
    String? pickupSlotId,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRetryAt,
    DateTime? cancelledAt,
    DateTime? completedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      status: status ?? this.status,
      paymentId: paymentId ?? this.paymentId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReference: paymentReference ?? this.paymentReference,
      retryCount: retryCount ?? this.retryCount,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupTime: pickupTime ?? this.pickupTime,
      pickupSlotId: pickupSlotId ?? this.pickupSlotId,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  String toString() =>
      'OrderModel(id: $id, items: ${items.length}, total: ₹$total, status: ${status.name})';
}
