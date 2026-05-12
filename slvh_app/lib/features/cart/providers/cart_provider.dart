import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slvh_app/features/cart/models/cart_item_model.dart';
import 'package:slvh_app/features/cart/services/cart_service.dart';
import 'package:slvh_app/features/products/models/pricing_tier_model.dart';
import 'package:slvh_app/features/products/models/product_model.dart';
import 'package:slvh_app/features/products/services/pricing_service.dart';
import 'package:slvh_app/features/products/services/product_service.dart';

/// Provider for managing shopping cart state
/// Handles add, remove, update operations
/// Persists to both SharedPreferences (local) and Firestore (cloud)
class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  final PricingService _pricingService = PricingService();
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  SharedPreferences? _prefs;

  CartProvider() {
    _init();
  }

  /// Initialize and load cart from local storage
  /// Firestore loading should be done via loadFromFirestore() after auth
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCart();
  }

  /// Load cart from Firestore (call after user authenticates)
  /// Merges with existing local cart (Firestore takes precedence)
  Future<void> loadFromFirestore() async {
    try {
      final firestoreItems = await _cartService.loadCart();
      if (firestoreItems.isNotEmpty) {
        _items.clear();
        _items.addAll(firestoreItems);
        notifyListeners();
        print('✅ Cart loaded from Firestore');
      }
    } catch (e) {
      print('⚠️ Failed to load cart from Firestore: $e');
      // Continue with local cart
    }
  }

  /// Get all cart items
  List<CartItemModel> get items => List.unmodifiable(_items);

  /// Get item count
  int get itemCount => _items.length;

  /// Get total number of units
  int get totalUnits => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Get cart subtotal
  double get subtotal =>
      _items.fold(0, (sum, item) => sum + item.getTotalPrice());

  /// Get estimated tax (5% for demo)
  double get estimatedTax => subtotal * 0.05;

  /// Get total with tax
  double get total => subtotal + estimatedTax;

  /// Check if cart is empty
  bool get isEmpty => _items.isEmpty;

  /// Add product to cart
  /// Respects product.maxOrderQty limit (silently caps quantity)
  Future<void> addToCart(
    ProductModel product, {
    int quantity = 1,
    PricingTierModel? selectedTier,
  }) async {
    // Validate quantity against max order limit
    int validQuantity = quantity;
    if (product.maxOrderQty != null && quantity > product.maxOrderQty!) {
      print('⚠️ Quantity exceeds max order limit (${product.maxOrderQty}). Capping quantity.');
      validQuantity = product.maxOrderQty!;
    }

    // Check if product already in cart
    final existingIndex =
        _items.indexWhere((item) => item.productId == product.id);

    if (existingIndex != -1) {
      // Update quantity
      final newTotal = _items[existingIndex].quantity + validQuantity;
      final cappedTotal = product.maxOrderQty != null 
          ? (newTotal > product.maxOrderQty! ? product.maxOrderQty! : newTotal)
          : newTotal;
      
      if (cappedTotal < _items[existingIndex].quantity) {
        print('⚠️ Adding quantity would exceed max order limit. Keeping current quantity.');
        await _saveCart();
        notifyListeners();
        return;
      }
      
      await updateQuantity(product.id, cappedTotal);
    } else {
      // Add new item
      final cartItem = CartItemModel.fromProduct(
        product,
        quantity: validQuantity,
        selectedTier: selectedTier,
      );
      _items.add(cartItem);
    }

    await _saveCart();
    notifyListeners();
  }

  /// Remove item from cart
  Future<void> removeItem(String productId) async {
    _items.removeWhere((item) => item.productId == productId);
    await _saveCart();
    notifyListeners();
  }

  /// Update item quantity and auto-select best pricing tier
  /// Respects product.maxOrderQty limit (silently caps quantity)
  Future<void> updateQuantity(String productId, int newQuantity) async {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index == -1) return;

    if (newQuantity <= 0) {
      await removeItem(productId);
      return;
    }

    // Get product to check max order quantity
    final product = await _productService.getProductById(productId);
    final cappedQuantity = product?.maxOrderQty != null
        ? (newQuantity > product!.maxOrderQty! ? product.maxOrderQty! : newQuantity)
        : newQuantity;

    if (cappedQuantity < newQuantity) {
      print('⚠️ Quantity capped to ${product!.maxOrderQty} (max order limit)');
    }

    // Update quantity
    _items[index].quantity = cappedQuantity;

    // Auto-select best matching pricing tier
    try {
      final tiers =
          await _pricingService.getPricingTiers(_items[index].productId);
      if (tiers.isNotEmpty) {
        // Find tier that matches quantity, or closest lower tier
        PricingTierModel? matchingTier;

        // First, try exact match
        matchingTier = tiers.firstWhere(
          (tier) => tier.quantity == newQuantity,
          orElse: () => tiers.first,
        );

        // If no exact match, find the largest tier <= quantity
        if (matchingTier.quantity != newQuantity) {
          final lowerTiers =
              tiers.where((tier) => tier.quantity <= newQuantity).toList();
          if (lowerTiers.isNotEmpty) {
            lowerTiers.sort((a, b) => b.quantity.compareTo(a.quantity));
            matchingTier = lowerTiers.first;
          }
        }

        _items[index].selectedTier = matchingTier;
      }
    } catch (e) {
      print('Error updating pricing tier: $e');
    }

    await _saveCart();
    notifyListeners();
  }

  /// Set a specific pricing tier for an item
  Future<void> setPricingTier(
    String productId,
    PricingTierModel tier,
  ) async {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index == -1) return;

    _items[index].selectedTier = tier;
    _items[index].quantity = tier.quantity.toInt();

    await _saveCart();
    notifyListeners();
  }

  /// Clear entire cart (local and Firestore)
  Future<void> clearCart() async {
    _items.clear();
    await _saveCart(); // This saves empty list to both local and Firestore
    await _cartService.clearCart(); // Also explicitly delete Firestore document
    notifyListeners();
  }

  /// Get specific item
  CartItemModel? getItem(String productId) {
    try {
      return _items.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  /// Load cart from local storage
  Future<void> _loadCart() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final cartJson = _prefs?.getString('cart');
      if (cartJson != null && cartJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(cartJson);
        _items.clear();
        _items.addAll(
          decodedList
              .map((item) => CartItemModel.fromJson(item))
              .whereType<CartItemModel>(),
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error loading cart: $e');
    }
  }

  /// Save cart to local storage AND Firestore
  Future<void> _saveCart() async {
    try {
      // Save to SharedPreferences (local)
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final cartJson = jsonEncode(
        _items.map((item) => item.toJson()).toList(),
      );
      await _prefs?.setString('cart', cartJson);

      // Save to Firestore (cloud)
      await _cartService.saveCart(_items);
    } catch (e) {
      print('Error saving cart: $e');
    }
  }

  /// Export cart items as JSON (for order placement)
  List<Map<String, dynamic>> exportCartItems() {
    return _items
        .map((item) => {
              'productId': item.productId,
              'productName': item.productName,
              'quantity': item.quantity,
              'unitPrice': item.getEffectivePrice(),
              'totalPrice': item.getTotalPrice(),
              'selectedTier': item.selectedTier != null
                  ? {
                      'quantity': item.selectedTier!.quantity,
                      'unit': item.selectedTier!.unit,
                      'price': item.selectedTier!.price,
                    }
                  : null,
            })
        .toList();
  }

  /// Get cart summary
  Map<String, dynamic> getCartSummary() {
    return {
      'itemCount': itemCount,
      'totalUnits': totalUnits,
      'subtotal': subtotal,
      'estimatedTax': estimatedTax,
      'total': total,
      'items': exportCartItems(),
    };
  }
}

/// Provider instance for use in widgets
// The app uses the `provider` package with ChangeNotifier.
// Use `ChangeNotifierProvider` in the widget tree (see lib/app.dart)
// Exporting a top-level provider instance is unnecessary for `provider`.

// If you migrate to Riverpod in the future, reintroduce StateNotifier and
// StateNotifierProvider here and add `flutter_riverpod` to `pubspec.yaml`.
