import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:slvh_app/features/cart/providers/cart_provider.dart';
import 'package:slvh_app/features/cart/widgets/cart_item_tile.dart';
import 'package:slvh_app/features/cart/widgets/cart_summary.dart';

/// Main shopping cart screen
/// Feature 8: Monitors product stock in real-time
class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize stock monitoring when cart screen opens
    Future.delayed(Duration.zero, _initializeStockMonitoring);
  }

  Future<void> _initializeStockMonitoring() async {
    if (!mounted) return;
    final cartProvider = context.read<CartProvider>();
    await cartProvider.initializeStockMonitoring();
  }

  @override
  void dispose() {
    // Cleanup listeners when cart screen closes
    final cartProvider = context.read<CartProvider>();
    cartProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CartScreenBody();
  }
}

/// Actual cart screen body (using Consumer)
class _CartScreenBody extends StatelessWidget {
  const _CartScreenBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        backgroundColor: Colors.orange[700],
        elevation: 0,
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              if (cartProvider.isEmpty) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cartProvider.itemCount} item${cartProvider.itemCount != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              // Cart items list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: cartProvider.itemCount,
                  itemBuilder: (context, index) {
                    final item = cartProvider.items[index];
                    final isOutOfStock = cartProvider.isItemOutOfStock(item.productId);
                    final isLowStock = cartProvider.isItemLowStock(item.productId);

                    return CartItemTile(
                      item: item,
                      cartProvider: cartProvider,
                      isOutOfStock: isOutOfStock,
                      isLowStock: isLowStock,
                    );
                  },
                ),
              ),

              // Cart summary
              CartSummary(
                cartProvider: cartProvider,
                onCheckout: () => _handleCheckout(context, cartProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build empty cart state UI
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Continue Shopping'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle checkout button tap
  void _handleCheckout(BuildContext context, CartProvider cartProvider) {
    // Get cart summary
    final cartSummary = cartProvider.getCartSummary();

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Order'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Items: ${cartSummary['itemCount']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Subtotal: ₹${cartSummary['subtotal'].toStringAsFixed(2)}',
              ),
              Text(
                'Tax: ₹${cartSummary['estimatedTax'].toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              Container(
                height: 1,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ₹${cartSummary['total'].toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Proceed to payment?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to checkout with cart summary
              final cartSummary = cartProvider.getCartSummary();
              context.push('/checkout', extra: cartSummary);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
            ),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }
}
