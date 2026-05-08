/// Pricing tier model for bulk purchasing options
/// Each product can have multiple price tiers (e.g., 1 KG = ₹60, 5 KG = ₹280)
class PricingTierModel {
  final String id;
  final double quantity;
  final String unit;
  final double price;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PricingTierModel({
    required this.id,
    required this.quantity,
    required this.unit,
    required this.price,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Calculate savings percentage compared to base price
  double calculateSavings(double basePrice) {
    if (basePrice <= 0) return 0;
    final pricePerUnit = price / quantity;
    final basePerUnit = basePrice / 1;
    if (basePerUnit <= 0) return 0;
    return ((basePerUnit - pricePerUnit) / basePerUnit * 100).roundToDouble();
  }

  /// Calculate effective price per unit
  double getPricePerUnit() {
    if (quantity <= 0) return price;
    return (price / quantity * 100).roundToDouble() / 100;
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'isDefault': isDefault,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from Firestore document
  factory PricingTierModel.fromFirestore(String id, Map<String, dynamic> data) {
    return PricingTierModel(
      id: id,
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      unit: data['unit'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      isDefault: data['isDefault'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'].toString())
          : null,
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'].toString())
          : null,
    );
  }

  /// Create a copy with modifications
  PricingTierModel copyWith({
    String? id,
    double? quantity,
    String? unit,
    double? price,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PricingTierModel(
      id: id ?? this.id,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'PricingTierModel(id: $id, quantity: $quantity, unit: $unit, price: $price, isDefault: $isDefault)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PricingTierModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          quantity == other.quantity &&
          unit == other.unit &&
          price == other.price &&
          isDefault == other.isDefault;

  @override
  int get hashCode =>
      id.hashCode ^
      quantity.hashCode ^
      unit.hashCode ^
      price.hashCode ^
      isDefault.hashCode;
}
