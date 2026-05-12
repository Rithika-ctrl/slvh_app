import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slvh_app/features/cart/models/cart_item_model.dart';
import 'package:slvh_app/features/cart/providers/cart_provider.dart';
import 'package:slvh_app/features/cart/services/cart_service.dart';
import 'package:slvh_app/features/products/models/product_model.dart';
import 'package:slvh_app/features/products/models/pricing_tier_model.dart';

/// Riverpod provider for CartProvider (ChangeNotifier)
final cartProvider = ChangeNotifierProvider((ref) => CartProvider());

/// Watch cart items as a stream for real-time updates
final cartItemsProvider = Provider((ref) {
  final cart = ref.watch(cartProvider);
  return cart.items;
});

/// Watch cart item count
final cartItemCountProvider = Provider((ref) {
  final cart = ref.watch(cartProvider);
  return cart.itemCount;
});

/// Watch total units in cart
final cartTotalUnitsProvider = Provider((ref) {
  final cart = ref.watch(cartProvider);
  return cart.totalUnits;
});

/// Watch cart subtotal
final cartSubtotalProvider = Provider((ref) {
  final cart = ref.watch(cartProvider);
  return cart.subtotal;
});

/// Watch cart tax
final cartTaxProvider = Provider((ref) {
  final cart = ref.watch(cartProvider);
  return cart.estimatedTax;
});

/// Watch cart total (subtotal + tax)
final cartTotalProvider = Provider((ref) {
  final cart = ref.watch(cartProvider);
  return cart.total;
});

/// Cart service provider
final cartServiceProvider = Provider((ref) => CartService());

/// Add item to cart
final addToCartProvider = FutureProvider.family<void, ({
  ProductModel product,
  int quantity,
  PricingTierModel? selectedTier,
})>((ref, params) async {
  final cart = ref.read(cartProvider);
  await cart.addToCart(
    params.product,
    quantity: params.quantity,
    selectedTier: params.selectedTier,
  );
});

/// Remove item from cart
final removeFromCartProvider = FutureProvider.family<void, String>((ref, productId) async {
  final cart = ref.read(cartProvider);
  await cart.removeItem(productId);
});

/// Update item quantity
final updateCartQuantityProvider = FutureProvider.family<void, (String, int)>((ref, params) async {
  final cart = ref.read(cartProvider);
  await cart.updateQuantity(params.$1, params.$2);
});

/// Set pricing tier for item
final setCartPricingTierProvider = FutureProvider.family<void, (String, PricingTierModel)>((ref, params) async {
  final cart = ref.read(cartProvider);
  await cart.setPricingTier(params.$1, params.$2);
});

/// Load cart from Firestore
final loadCartFromFirestoreProvider = FutureProvider((ref) async {
  final cart = ref.read(cartProvider);
  await cart.loadFromFirestore();
});

/// Clear cart
final clearCartProvider = FutureProvider((ref) async {
  final cart = ref.read(cartProvider);
  await cart.clearCart();
});

/// Get specific cart item
final getCartItemProvider = Provider.family<CartItemModel?, String>((ref, productId) {
  final cart = ref.watch(cartProvider);
  return cart.getItem(productId);
});
