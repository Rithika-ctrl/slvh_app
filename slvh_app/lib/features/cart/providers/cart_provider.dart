import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slvh_app/features/cart/models/cart_item_model.dart';
import 'package:slvh_app/features/products/models/pricing_tier_model.dart';
import 'package:slvh_app/features/products/models/product_model.dart';
import 'package:slvh_app/features/products/services/pricing_service.dart';

/// Provider for managing shopping cart state
/// Handles add, remove, update operations and local persistence
class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  final PricingService _pricingService = PricingService();
  SharedPreferences? _prefs;

  CartProvider() {
    _init();
  }

  /// Initialize and load cart from local storage
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCart();
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
  Future<void> addToCart(
    ProductModel product, {
    int quantity = 1,
    PricingTierModel? selectedTier,
  }) async {
    // Check if product already in cart
    final existingIndex =
        _items.indexWhere((item) => item.productId == product.id);

    if (existingIndex != -1) {
      // Update quantity
      await updateQuantity(product.id, _items[existingIndex].quantity + quantity);
    } else {
      // Add new item
      final cartItem = CartItemModel.fromProduct(
        product,
        quantity: quantity,
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
  Future<void> updateQuantity(String productId, int newQuantity) async {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index == -1) return;

    if (newQuantity <= 0) {
      await removeItem(productId);
      return;
    }

    // Update quantity
    _items[index].quantity = newQuantity;

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

  /// Clear entire cart
  Future<void> clearCart() async {
    _items.clear();
    await _saveCart();
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

  /// Save cart to local storage
  Future<void> _saveCart() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final cartJson = jsonEncode(
        _items.map((item) => item.toJson()).toList(),
      );
      await _prefs?.setString('cart', cartJson);
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
final cartProvider = ChangeNotifierProvider<CartProvider>((ref) {
  return CartProvider();
});

/// Riverpod-style provider for cart items
final cartItemsProvider = StateNotifierProvider<CartNotifier, List<CartItemModel>>((ref) {
  return CartNotifier();
});

/// State notifier for Riverpod integration
class CartNotifier extends StateNotifier<List<CartItemModel>> {
  CartNotifier() : super([]) {
    _init();
  }

  final PricingService _pricingService = PricingService();
  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCart();
  }

  Future<void> addToCart(ProductModel product, {int quantity = 1}) async {
    final existingIndex =
        state.indexWhere((item) => item.productId == product.id);

    if (existingIndex != -1) {
      await updateQuantity(product.id, state[existingIndex].quantity + quantity);
    } else {
      final cartItem = CartItemModel.fromProduct(product, quantity: quantity);
      state = [...state, cartItem];
      await _saveCart();
    }
  }

  Future<void> removeItem(String productId) async {
    state = state.where((item) => item.productId != productId).toList();
    await _saveCart();
  }

  Future<void> updateQuantity(String productId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeItem(productId);
      return;
    }

    final newState = [...state];
    final index = newState.indexWhere((item) => item.productId == productId);
    if (index != -1) {
      newState[index].quantity = newQuantity;
      state = newState;
      await _saveCart();
    }
  }

  Future<void> clearCart() async {
    state = [];
    if (_prefs != null) {
      await _prefs!.remove('cart');
    }
  }

  Future<void> _loadCart() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final cartJson = _prefs?.getString('cart');
      if (cartJson != null && cartJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(cartJson);
        state = decodedList
            .map((item) => CartItemModel.fromJson(item))
            .whereType<CartItemModel>()
            .toList();
      }
    } catch (e) {
      print('Error loading cart: $e');
    }
  }

  Future<void> _saveCart() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final cartJson = jsonEncode(
        state.map((item) => item.toJson()).toList(),
      );
      await _prefs?.setString('cart', cartJson);
    } catch (e) {
      print('Error saving cart: $e');
    }
  }
}
