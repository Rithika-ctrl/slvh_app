/// Product Model
/// 
/// Represents a product in the SLVH Smart Shop.
/// Products belong to categories and have inventory management.

class ProductModel {
  final String id;
  final String name;
  final String nameLowercase;
  final String description;
  final double price;
  final double? discountPrice;
  final List<String> images;
  final String categoryId;
  final int stock;
  final String unitType; // e.g., "250ml", "500g", "pack", "bottle" (deprecated, use unitLabel)
  final String unitLabel; // e.g., "kg", "piece", "litre", "dozen", "packet"
  final bool isActive;
  final double? rating;
  final int? reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    String? nameLowercase,
    required this.description,
    required this.price,
    this.discountPrice,
    required this.images,
    required this.categoryId,
    required this.stock,
    required this.unitType,
    required this.unitLabel,
    required this.isActive,
    this.rating,
    this.reviewCount,
    required this.createdAt,
    required this.updatedAt,
  }) : nameLowercase = nameLowercase ?? name.toLowerCase();

  /// Get discount percentage if available
  double? get discountPercentage {
    if (discountPrice == null) return null;
    return ((price - discountPrice!) / price * 100).round().toDouble();
  }

  /// Get the effective price (considering discount)
  double get effectivePrice => discountPrice ?? price;

  /// Check if product is in stock
  bool get isInStock => stock > 0;

  /// Convert Firestore document to ProductModel
  factory ProductModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return ProductModel(
      id: docId,
      name: data['name'] as String? ?? '',
      nameLowercase: data['name_lowercase'] as String? ?? (data['name'] as String? ?? '').toLowerCase(),
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      discountPrice: (data['discountPrice'] as num?)?.toDouble(),
      images: List<String>.from(data['images'] as List? ?? []),
      categoryId: data['categoryId'] as String? ?? '',
      stock: data['stock'] as int? ?? 0,
      unitType: data['unitType'] as String? ?? '',
      unitLabel: data['unit_label'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      rating: (data['rating'] as num?)?.toDouble(),
      reviewCount: data['reviewCount'] as int?,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert ProductModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'name_lowercase': nameLowercase,
      'description': description,
      'price': price,
      'discountPrice': discountPrice,
      'images': images,
      'categoryId': categoryId,
      'stock': stock,
      'unitType': unitType,
      'unit_label': unitLabel,
      'isActive': isActive,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create a copy with updated fields
  ProductModel copyWith({
    String? id,
    String? name,
    String? nameLowercase,
    String? description,
    double? price,
    double? discountPrice,
    List<String>? images,
    String? categoryId,
    int? stock,
    String? unitType,
    String? unitLabel,
    bool? isActive,
    double? rating,
    int? reviewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nameLowercase: nameLowercase ?? this.nameLowercase,
      description: description ?? this.description,
      price: price ?? this.price,
      discountPrice: discountPrice ?? this.discountPrice,
      images: images ?? this.images,
      categoryId: categoryId ?? this.categoryId,
      stock: stock ?? this.stock,
      unitType: unitType ?? this.unitType,
      unitLabel: unitLabel ?? this.unitLabel,
      isActive: isActive ?? this.isActive,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ProductModel(id: $id, name: $name, price: ₹$price)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
