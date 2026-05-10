/// BannerModel
///
/// Represents a promotional banner shown on the customer HomeScreen carousel.
/// Stored in Firestore collection: `banners/`
///
/// Firestore document structure:
/// ```
/// {
///   "imageUrl":  "https://...",   // Firebase Storage URL
///   "deeplink":  "/products/xyz", // optional GoRouter path
///   "isActive":  true,
///   "sortOrder": 0,               // ascending → lower appears first
///   "createdAt": Timestamp,
///   "updatedAt": Timestamp,
/// }
/// ```

import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  final String id;
  final String imageUrl;
  final String? deeplink;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BannerModel({
    required this.id,
    required this.imageUrl,
    this.deeplink,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Firestore ─────────────────────────────────────────────────────────────

  factory BannerModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return BannerModel(
      id: docId,
      imageUrl: data['imageUrl'] as String? ?? '',
      deeplink: data['deeplink'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      sortOrder: data['sortOrder'] as int? ?? 0,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'imageUrl': imageUrl,
        'deeplink': deeplink,
        'isActive': isActive,
        'sortOrder': sortOrder,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  // ── Helpers ───────────────────────────────────────────────────────────────

  BannerModel copyWith({
    String? id,
    String? imageUrl,
    String? deeplink,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BannerModel(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      deeplink: deeplink ?? this.deeplink,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BannerModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BannerModel(id: $id, sortOrder: $sortOrder, isActive: $isActive)';
}