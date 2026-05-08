import 'package:cloud_firestore/cloud_firestore.dart';

/// Payment status enum
enum PaymentStatus {
  pending('Pending'),
  verificationPending('Verification Pending'),
  verified('Verified'),
  rejected('Rejected'),
  cancelled('Cancelled');

  final String label;
  const PaymentStatus(this.label);

  /// Convert string to enum
  static PaymentStatus fromString(String value) {
    return values.firstWhere(
      (status) => status.name == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

/// Model for payment/payment verification document
class PaymentModel {
  final String id; // Payment ID (document ID)
  final String orderId; // Associated order ID
  final String upiId; // Shop's UPI ID (e.g., "shop@okhdfcbank")
  final double amount; // Payment amount in rupees
  final String customerPhone; // Customer phone number
  final String? screenshotUrl; // Firebase Storage URL of payment proof
  final PaymentStatus status; // Payment verification status
  final String? rejectionReason; // Reason if rejected
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final DateTime? updatedAt;

  PaymentModel({
    required this.id,
    required this.orderId,
    required this.upiId,
    required this.amount,
    required this.customerPhone,
    this.screenshotUrl,
    this.status = PaymentStatus.pending,
    this.rejectionReason,
    required this.createdAt,
    this.verifiedAt,
    this.updatedAt,
  });

  /// Check if payment is verified
  bool get isVerified => status == PaymentStatus.verified;

  /// Check if verification pending
  bool get isPendingVerification =>
      status == PaymentStatus.verificationPending;

  /// Check if payment is rejected
  bool get isRejected => status == PaymentStatus.rejected;

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'upiId': upiId,
      'amount': amount,
      'customerPhone': customerPhone,
      'screenshotUrl': screenshotUrl,
      'status': status.name,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt,
      'verifiedAt': verifiedAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from Firestore document
  factory PaymentModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return PaymentModel(
      id: id,
      orderId: data['orderId'] ?? '',
      upiId: data['upiId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      customerPhone: data['customerPhone'] ?? '',
      screenshotUrl: data['screenshotUrl'],
      status: PaymentStatus.fromString(data['status'] ?? 'pending'),
      rejectionReason: data['rejectionReason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create a copy with modifications
  PaymentModel copyWith({
    String? id,
    String? orderId,
    String? upiId,
    double? amount,
    String? customerPhone,
    String? screenshotUrl,
    PaymentStatus? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? verifiedAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      upiId: upiId ?? this.upiId,
      amount: amount ?? this.amount,
      customerPhone: customerPhone ?? this.customerPhone,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'PaymentModel(id: $id, orderId: $orderId, amount: ₹$amount, status: ${status.name})';
}
