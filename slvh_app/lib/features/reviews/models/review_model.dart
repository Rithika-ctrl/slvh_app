import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single product review stored at reviews/{review_id}.
///
/// Firestore schema:
/// ```
/// reviews/{review_id} {
///   product_id   : String
///   user_id      : String   (customer phone)
///   order_id     : String   (the completed order that unlocks the review)
///   rating       : Number   (1–5)
///   comment      : String   (optional)
///   created_at   : Timestamp
///   updated_at   : Timestamp (null on first write)
/// }
/// ```
class ReviewModel {
  final String id;
  final String productId;
  final String userId;       // customer phone number
  final String orderId;      // completed order that unlocked this review
  final double rating;       // 1–5
  final String comment;      // optional free-text
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ReviewModel({
    required this.id,
    required this.productId,
    required this.userId,
    required this.orderId,
    required this.rating,
    this.comment = '',
    required this.createdAt,
    this.updatedAt,
  });

  // ── Serialisation ──────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'product_id': productId,
        'user_id': userId,
        'order_id': orderId,
        'rating': rating,
        'comment': comment,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': updatedAt != null ? FieldValue.serverTimestamp() : null,
      };

  factory ReviewModel.fromFirestore(String id, Map<String, dynamic> data) =>
      ReviewModel(
        id: id,
        productId: data['product_id'] as String? ?? '',
        userId: data['user_id'] as String? ?? '',
        orderId: data['order_id'] as String? ?? '',
        rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
        comment: data['comment'] as String? ?? '',
        createdAt:
            (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      );

  ReviewModel copyWith({
    String? id,
    String? productId,
    String? userId,
    String? orderId,
    double? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ReviewModel(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        userId: userId ?? this.userId,
        orderId: orderId ?? this.orderId,
        rating: rating ?? this.rating,
        comment: comment ?? this.comment,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  String toString() =>
      'ReviewModel(id: $id, product: $productId, rating: $rating)';
}