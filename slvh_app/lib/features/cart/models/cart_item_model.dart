import 'package:slvh_app/features/products/models/pricing_tier_model.dart';
import 'package:slvh_app/features/products/models/product_model.dart';

/// Cart item model combining product data with cart-specific information
class CartItemModel {
  final String productId;
  final String productName;
  final double basePrice;
  final List<String> imageUrls;
  final String categoryId;
  late int quantity;
  late PricingTierModel? selectedTier;

  CartItemModel({
    required this.productId,
    required this.productName,
    required this.basePrice,
    required this.imageUrls,
    required this.categoryId,
    this.quantity = 1,
    this.selectedTier,
  });

  /// Create from ProductModel
  factory CartItemModel.fromProduct(
    ProductModel product, {
    int quantity = 1,
    PricingTierModel? selectedTier,
  }) {
    return CartItemModel(
      productId: product.id,
      productName: product.name,
      basePrice: product.price,
      imageUrls: product.images,
      categoryId: product.categoryId,
      quantity: quantity,
      selectedTier: selectedTier,
    );
  }

  /// Get effective price (from selected tier or base price)
  double getEffectivePrice() {
    if (selectedTier == null) {
      return basePrice;
    }
    return selectedTier!.price / selectedTier!.quantity;
  }

  /// Get total price for this item
  double getTotalPrice() {
    if (selectedTier == null) {
      return basePrice * quantity;
    }
    // If tier is selected, use tier's total price
    return selectedTier!.price;
  }

  /// Check if a pricing tier matches the current quantity
  bool isTierMatch(PricingTierModel tier) {
    return quantity == tier.quantity;
  }

  /// Get savings percentage
  double getSavingsPercent() {
    if (selectedTier == null) return 0;
    return selectedTier!.calculateSavings(basePrice);
  }

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'basePrice': basePrice,
      'imageUrls': imageUrls,
      'categoryId': categoryId,
      'quantity': quantity,
      'selectedTier': selectedTier != null
          ? {
              'id': selectedTier!.id,
              'quantity': selectedTier!.quantity,
              'unit': selectedTier!.unit,
              'price': selectedTier!.price,
            }
          : null,
    };
  }

  /// Create from JSON
  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    PricingTierModel? tier;
    if (json['selectedTier'] != null) {
      final tierData = json['selectedTier'] as Map<String, dynamic>;
      tier = PricingTierModel(
        id: tierData['id'] ?? '',
        quantity: (tierData['quantity'] as num).toDouble(),
        unit: tierData['unit'] ?? '',
        price: (tierData['price'] as num).toDouble(),
      );
    }

    return CartItemModel(
      productId: json['productId'],
      productName: json['productName'],
      basePrice: (json['basePrice'] as num).toDouble(),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      categoryId: json['categoryId'] ?? '',
      quantity: json['quantity'] ?? 1,
      selectedTier: tier,
    );
  }

  /// Create a copy with modifications
  CartItemModel copyWith({
    String? productId,
    String? productName,
    double? basePrice,
    List<String>? imageUrls,
    String? categoryId,
    int? quantity,
    PricingTierModel? selectedTier,
  }) {
    return CartItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      basePrice: basePrice ?? this.basePrice,
      imageUrls: imageUrls ?? this.imageUrls,
      categoryId: categoryId ?? this.categoryId,
      quantity: quantity ?? this.quantity,
      selectedTier: selectedTier ?? this.selectedTier,
    );
  }

  @override
  String toString() =>
      'CartItemModel(productId: $productId, quantity: $quantity, tier: ${selectedTier?.unit})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemModel && productId == other.productId;

  @override
  int get hashCode => productId.hashCode;
}
