import 'package:flutter/material.dart';
import 'package:slvh_app/features/inventory/services/inventory_service.dart';
import 'package:slvh_app/features/inventory/widgets/stock_indicator.dart';
import 'package:slvh_app/features/products/models/product_model.dart';

/// Admin inventory management screen
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryService _inventoryService = InventoryService();
  int _selectedFilter = 0; // 0: All, 1: Low Stock, 2: Out of Stock

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory Management'),
          centerTitle: true,
          elevation: 0,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'All Products'),
              Tab(text: 'Low Stock'),
              Tab(text: 'Out of Stock'),
            ],
            onTap: (index) {
              setState(() => _selectedFilter = index);
            },
          ),
        ),
        body: TabBarView(
          children: [
            _buildAllProductsTab(),
            _buildLowStockTab(),
            _buildOutOfStockTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showThresholdSettings,
          tooltip: 'Settings',
          child: const Icon(Icons.settings),
        ),
      ),
    );
  }

  /// Tab 1: All products with stock levels
  Widget _buildAllProductsTab() {
    return StreamBuilder<List<ProductModel>>(
      stream: _inventoryService.watchAllProductsWithStock(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final products = snapshot.data ?? [];

        if (products.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('No products found'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh is automatic with StreamBuilder
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product);
            },
          ),
        );
      },
    );
  }

  /// Tab 2: Low stock products
  Widget _buildLowStockTab() {
    return StreamBuilder<List<ProductModel>>(
      stream: _inventoryService.watchLowStockProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data ?? [];

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_outline,
                    size: 48, color: Colors.green),
                SizedBox(height: 16),
                Text('All products have sufficient stock!'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(product);
          },
        );
      },
    );
  }

  /// Tab 3: Out of stock products
  Widget _buildOutOfStockTab() {
    return FutureBuilder<List<ProductModel>>(
      future: _inventoryService.getOutOfStockProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data ?? [];

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_outline,
                    size: 48, color: Colors.green),
                SizedBox(height: 16),
                Text('No out of stock products'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(product);
          },
        );
      },
    );
  }

  /// Product card with stock info and adjust button
  Widget _buildProductCard(ProductModel product) {
    return FutureBuilder<int>(
      future: _inventoryService.getLowStockThreshold(),
      builder: (context, thresholdSnapshot) {
        final threshold = thresholdSnapshot.data ?? 10;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name and stock indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${product.id}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StockIndicator(
                      stock: product.stock,
                      threshold: threshold,
                      showLabel: true,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Stock details
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Stock',
                            style:
                                TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${product.stock} units',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Low Stock Threshold',
                            style:
                                TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$threshold units',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showAdjustStockDialog(product, threshold),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Adjust Stock'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAdjustmentHistory(product.id),
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('History'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show dialog to adjust stock
  void _showAdjustStockDialog(ProductModel product, int threshold) {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();
    String operation = 'add'; // 'add' or 'subtract'

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Adjust Stock: ${product.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current stock display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Stock:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${product.stock} units',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Operation selection
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(label: Text('Add'), value: 'add'),
                          ButtonSegment(
                              label: Text('Remove'), value: 'subtract'),
                        ],
                        selected: {operation},
                        onSelectionChanged: (selection) {
                          setState(() => operation = selection.first);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quantity input
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'Enter quantity',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                ),
                const SizedBox(height: 12),

                // Reason input
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Why are you adjusting stock?',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
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
                _adjustStock(
                  product.id,
                  quantityController.text,
                  reasonController.text,
                  operation,
                );
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  /// Adjust stock in Firestore
  void _adjustStock(
    String productId,
    String quantityStr,
    String reason,
    String operation,
  ) async {
    if (quantityStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a quantity')),
      );
      return;
    }

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }

    try {
      int quantity = int.parse(quantityStr);
      if (operation == 'subtract') {
        quantity = -quantity;
      }

      await _inventoryService.adjustStock(
        productId: productId,
        quantityChange: quantity,
        reason: reason,
        adminId: 'admin@smartshop.com', // TODO: Get actual admin ID
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Stock updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  /// Show stock adjustment history
  void _showAdjustmentHistory(String productId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          children: [
            AppBar(
              title: const Text('Adjustment History'),
              automaticallyImplyLeading: true,
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream:
                    _inventoryService.watchStockAdjustmentHistory(productId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final history = snapshot.data ?? [];

                  if (history.isEmpty) {
                    return const Center(
                      child: Text('No adjustments yet'),
                    );
                  }

                  return ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final adjustment = history[index];
                      final change = adjustment['quantityChange'] as int;
                      final isPositive = change > 0;

                      return ListTile(
                        leading: Icon(
                          isPositive
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          '${isPositive ? '+' : ''}$change units',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                        ),
                        subtitle: Text(adjustment['reason'] ?? ''),
                        trailing: Text(
                          adjustment['timestamp']
                              ?.toDate()
                              ?.toString()
                              .substring(0, 10) ??
                              '',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show threshold settings dialog
  void _showThresholdSettings() async {
    final currentThreshold = await _inventoryService.getLowStockThreshold();
    final controller = TextEditingController(text: currentThreshold.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Low Stock Threshold Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set the quantity level that triggers low stock warnings:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Low Stock Threshold',
                hintText: 'e.g., 10',
                border: OutlineInputBorder(),
                suffixText: 'units',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                int threshold = int.parse(controller.text);
                if (threshold < 0) {
                  throw Exception('Threshold must be positive');
                }

                await _inventoryService.setLowStockThreshold(threshold);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Threshold set to $threshold')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
