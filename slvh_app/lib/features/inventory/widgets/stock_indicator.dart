import 'package:flutter/material.dart';

/// Widget to display stock status with color coding
/// Green: OK (above threshold)
/// Yellow: Low (at or below threshold)
/// Red: Out of Stock (zero)
class StockIndicator extends StatelessWidget {
  final int stock;
  final int threshold;
  final bool showLabel;
  final TextStyle? textStyle;

  const StockIndicator({
    Key? key,
    required this.stock,
    required this.threshold,
    this.showLabel = true,
    this.textStyle,
  }) : super(key: key);

  /// Get stock status based on level
  StockStatus _getStatus() {
    if (stock == 0) {
      return StockStatus.outOfStock;
    } else if (stock <= threshold) {
      return StockStatus.low;
    } else {
      return StockStatus.ok;
    }
  }

  Color _getColor() {
    switch (_getStatus()) {
      case StockStatus.ok:
        return Colors.green;
      case StockStatus.low:
        return Colors.amber;
      case StockStatus.outOfStock:
        return Colors.red;
    }
  }

  Color _getBackgroundColor() {
    switch (_getStatus()) {
      case StockStatus.ok:
        return Colors.green.withOpacity(0.1);
      case StockStatus.low:
        return Colors.amber.withOpacity(0.1);
      case StockStatus.outOfStock:
        return Colors.red.withOpacity(0.1);
    }
  }

  String _getStatusText() {
    switch (_getStatus()) {
      case StockStatus.ok:
        return 'In Stock';
      case StockStatus.low:
        return 'Low Stock';
      case StockStatus.outOfStock:
        return 'Out of Stock';
    }
  }

  IconData _getIcon() {
    switch (_getStatus()) {
      case StockStatus.ok:
        return Icons.check_circle;
      case StockStatus.low:
        return Icons.warning;
      case StockStatus.outOfStock:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _getStatus();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        border: Border.all(color: _getColor(), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            color: _getColor(),
            size: 16,
          ),
          const SizedBox(width: 4),
          if (showLabel)
            Text(
              _getStatusText(),
              style: (textStyle ?? const TextStyle()).copyWith(
                color: _getColor(),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              '$stock',
              style: (textStyle ?? const TextStyle()).copyWith(
                color: _getColor(),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

/// Stock badge showing just the number and color
class StockBadge extends StatelessWidget {
  final int stock;
  final int threshold;
  final double size;

  const StockBadge({
    Key? key,
    required this.stock,
    required this.threshold,
    this.size = 24,
  }) : super(key: key);

  Color _getColor() {
    if (stock == 0) {
      return Colors.red;
    } else if (stock <= threshold) {
      return Colors.amber;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getColor(),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          stock.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Compact stock row for list items
class StockRow extends StatelessWidget {
  final int stock;
  final int threshold;
  final String label;

  const StockRow({
    Key? key,
    required this.stock,
    required this.threshold,
    this.label = 'Stock',
  }) : super(key: key);

  Color _getColor() {
    if (stock == 0) {
      return Colors.red;
    } else if (stock <= threshold) {
      return Colors.amber;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _getColor().withOpacity(0.1),
            border: Border.all(color: _getColor()),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            stock == 0 ? 'Out of Stock' : '$stock units',
            style: TextStyle(
              color: _getColor(),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

/// Low stock warning widget for product cards
class LowStockWarning extends StatelessWidget {
  final int stock;
  final int threshold;
  final VoidCallback? onTap;

  const LowStockWarning({
    Key? key,
    required this.stock,
    required this.threshold,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Don't show if stock is OK
    if (stock > threshold) {
      return const SizedBox.shrink();
    }

    final isOutOfStock = stock == 0;
    final backgroundColor =
        isOutOfStock ? Colors.red[50] : Colors.orange[50];
    final borderColor = isOutOfStock ? Colors.red : Colors.orange;
    final textColor = isOutOfStock ? Colors.red[700] : Colors.orange[700];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              isOutOfStock ? Icons.error : Icons.warning,
              color: textColor,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isOutOfStock
                    ? 'Out of Stock - Tap to Reorder'
                    : 'Low Stock - Only $stock left',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed stock info card
class StockInfoCard extends StatelessWidget {
  final String productName;
  final int stock;
  final int threshold;
  final String productId;
  final VoidCallback? onAdjustStock;

  const StockInfoCard({
    Key? key,
    required this.productName,
    required this.stock,
    required this.threshold,
    required this.productId,
    this.onAdjustStock,
  }) : super(key: key);

  Color _getColor() {
    if (stock == 0) {
      return Colors.red;
    } else if (stock <= threshold) {
      return Colors.amber;
    } else {
      return Colors.green;
    }
  }

  String _getStatus() {
    if (stock == 0) {
      return 'Out of Stock';
    } else if (stock <= threshold) {
      return 'Low Stock';
    } else {
      return 'In Stock';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getColor().withOpacity(0.1),
                    border: Border.all(color: _getColor()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatus(),
                    style: TextStyle(
                      color: _getColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Stock',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$stock units',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getColor(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Low Stock Threshold',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$threshold units',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (onAdjustStock != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAdjustStock,
                  icon: const Icon(Icons.edit),
                  label: const Text('Adjust Stock'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Enum for stock status
enum StockStatus {
  ok,
  low,
  outOfStock,
}
