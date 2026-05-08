import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:slvh_app/features/cart/models/cart_item_model.dart';
import 'package:slvh_app/features/cart/providers/cart_provider.dart';

/// Individual cart item tile with quantity controls
class CartItemTile extends StatelessWidget {
  final CartItemModel item;
  final CartProvider cartProvider;
  final VoidCallback? onRemove;

  const CartItemTile({
    Key? key,
    required this.item,
    required this.cartProvider,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrls.isNotEmpty ? item.imageUrls.first : '';
    final savings = item.getSavingsPercent();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Dismissible(
        key: ValueKey(item.productId),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          cartProvider.removeItem(item.productId);
          onRemove?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.productName} removed from cart'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        background: Container(
          color: Colors.red[100],
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: Icon(Icons.delete, color: Colors.red[700]),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey[300]),
                  errorWidget: (context, url, error) =>
                      Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Colors.grey[600]),
                      ),
                ),
              ),
              const SizedBox(width: 12),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      item.productName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Price info
                    Row(
                      children: [
                        Text(
                          '₹${item.getEffectivePrice().toStringAsFixed(2)}/unit',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (savings > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Save ${savings.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Total price
                    Text(
                      'Total: ₹${item.getTotalPrice().toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                    ),
                  ],
                ),
              ),

              // Quantity controls
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _QuantityControl(
                    quantity: item.quantity,
                    onIncrement: () async {
                      await cartProvider.updateQuantity(
                        item.productId,
                        item.quantity + 1,
                      );
                    },
                    onDecrement: () async {
                      if (item.quantity > 1) {
                        await cartProvider.updateQuantity(
                          item.productId,
                          item.quantity - 1,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (item.selectedTier != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.selectedTier!.unit}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quantity control widget with increment/decrement buttons
class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QuantityControl({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.remove, size: 16, color: Colors.orange[700]),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              quantity.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.add, size: 16, color: Colors.orange[700]),
            ),
          ),
        ],
      ),
    );
  }
}
