import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../products/models/product_model.dart';
import '../../products/services/cloudinary_upload_service.dart';
import '../../products/services/pricing_service.dart';
import '../../products/services/product_service.dart';

class ProductListAdmin extends StatefulWidget {
  const ProductListAdmin({super.key});

  @override
  State<ProductListAdmin> createState() => _ProductListAdminState();
}

class _ProductListAdminState extends State<ProductListAdmin> {
  final _productService = ProductService();
  final _pricingService = PricingService();
  final _firestore = FirebaseFirestore.instance;
  final _cloudinaryService = CloudinaryUploadService();
  bool _showInactive = true;
  bool _isUploadingCsv = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('Product Management'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            onPressed: () => setState(() => _showInactive = !_showInactive),
            icon: Icon(_showInactive ? Icons.visibility_off : Icons.visibility),
          ),
          IconButton(
            tooltip: 'Upload CSV',
            onPressed: _isUploadingCsv ? null : _uploadCsv,
            icon: _isUploadingCsv
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/products/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream: _productService.watchAllProducts(onlyActive: !_showInactive),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Could not load products: ${snapshot.error}'));
          }

          final products = snapshot.data ?? const [];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToolbar(context, products.length),
                    const SizedBox(height: 16),
                    Expanded(
                      child: products.isEmpty
                          ? const _EmptyProducts()
                          : _ProductTable(
                              products: products,
                              onEdit: _editProduct,
                              onToggleActive: _toggleActive,
                              onDelete: _confirmDelete,
                              onManagePricing: _managePricing,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count products',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _showInactive
                    ? 'Showing active and inactive products'
                    : 'Showing active products only',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isUploadingCsv ? null : _uploadCsv,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('CSV Upload'),
              ),
              ElevatedButton.icon(
                onPressed: () => context.push('/admin/products/add'),
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summary,
                const SizedBox(height: 14),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: summary),
              actions,
            ],
          );
        },
      ),
    );
  }

  void _editProduct(ProductModel product) {
    context.push('/admin/products/${product.id}/edit', extra: product);
  }

  void _managePricing(ProductModel product) {
    context.push('/admin/products/${product.id}/pricing', extra: product);
  }

  Future<void> _toggleActive(ProductModel product, bool isActive) async {
    final success = await _productService.updateProduct(
      productId: product.id,
      isActive: isActive,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${product.name} ${isActive ? 'enabled' : 'disabled'}'
              : 'Could not update product',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ProductModel product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'This permanently deletes "${product.name}", its uploaded images, and its pricing tiers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    final success = await _deleteProduct(product);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Product deleted' : 'Could not delete product'),
      ),
    );
  }

  Future<bool> _deleteProduct(ProductModel product) async {
    try {
      await _cloudinaryService.deleteImagesByUrls(product.images);

      await _pricingService.deleteAllPricingTiers(product.id);
      return _productService.deleteProduct(product.id);
    } catch (_) {
      return false;
    }
  }

  Future<void> _uploadCsv() async {
    setState(() => _isUploadingCsv = true);

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (picked == null || picked.files.single.bytes == null) return;

      final content = String.fromCharCodes(picked.files.single.bytes!);
      final rows = _parseCsv(content);
      if (rows.length < 2) {
        throw Exception(
            'CSV must include a header row and at least one product.');
      }

      final headers = rows.first.map((value) => value.trim()).toList();
      final batch = _firestore.batch();
      var created = 0;

      for (final row in rows.skip(1)) {
        if (row.every((value) => value.trim().isEmpty)) continue;

        final data = <String, String>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          data[headers[i]] = row[i].trim();
        }

        final doc = _firestore.collection('products').doc();
        batch.set(doc, {
          'name': _csvRequired(data, 'name'),
          'description': data['description'] ?? '',
          'price': double.parse(_csvRequired(data, 'price')),
          'discountPrice': _parseOptionalDouble(data['discountPrice']),
          'images': _parseImageUrls(data['images'] ?? data['imageUrl'] ?? ''),
          'categoryId': _csvRequired(data, 'categoryId'),
          'stock': int.parse(data['stock'] ?? '0'),
          'unitType': _csvRequired(data, 'unitType'),
          'isActive': _parseBool(data['isActive'] ?? 'true'),
          'rating': null,
          'reviewCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        created++;
      }

      if (created == 0) {
        throw Exception('No product rows found.');
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $created products from CSV')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingCsv = false);
    }
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    final row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final next = i + 1 < input.length ? input[i + 1] : '';

      if (char == '"' && inQuotes && next == '"') {
        cell.write('"');
        i++;
      } else if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        row.add(cell.toString());
        cell.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && next == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        rows.add(List<String>.from(row));
        row.clear();
      } else {
        cell.write(char);
      }
    }

    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }

    return rows;
  }

  String _csvRequired(Map<String, String> data, String key) {
    final value = data[key]?.trim();
    if (value == null || value.isEmpty) {
      throw Exception('Missing required "$key" value.');
    }
    return value;
  }

  double? _parseOptionalDouble(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.parse(value.trim());
  }

  bool _parseBool(String value) {
    return ['true', '1', 'yes', 'y', 'active'].contains(value.toLowerCase());
  }

  List<String> _parseImageUrls(String value) {
    return value
        .split('|')
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }
}

class _ProductTable extends StatelessWidget {
  final List<ProductModel> products;
  final ValueChanged<ProductModel> onEdit;
  final void Function(ProductModel product, bool isActive) onToggleActive;
  final ValueChanged<ProductModel> onDelete;
  final ValueChanged<ProductModel> onManagePricing;

  const _ProductTable({
    required this.products,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onManagePricing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      AppColors.orangePale.withOpacity(0.9),
                    ),
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Stock')),
                      DataColumn(label: Text('Active')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final product in products)
                        DataRow(
                          cells: [
                            DataCell(_ProductIdentity(product: product)),
                            DataCell(Text(_formatPrice(product))),
                            DataCell(
                                Text('${product.stock} ${product.unitType}')),
                            DataCell(
                              Switch(
                                value: product.isActive,
                                activeColor: AppColors.success,
                                onChanged: (value) =>
                                    onToggleActive(product, value),
                              ),
                            ),
                            DataCell(
                              Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => onEdit(product),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Pricing tiers',
                                    onPressed: () => onManagePricing(product),
                                    icon: const Icon(Icons.layers_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => onDelete(product),
                                    color: AppColors.error,
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _formatPrice(ProductModel product) {
    final base = 'Rs ${product.price.toStringAsFixed(0)}';
    if (product.discountPrice == null) return base;
    return 'Rs ${product.discountPrice!.toStringAsFixed(0)} ($base)';
  }
}

class _ProductIdentity extends StatelessWidget {
  final ProductModel product;

  const _ProductIdentity({required this.product});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.orangePale,
            borderRadius: BorderRadius.circular(8),
          ),
          child: product.images.isEmpty
              ? const Icon(Icons.image_outlined, color: AppColors.textHint)
              : Image.network(product.images.first, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 250,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                product.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                color: AppColors.textHint, size: 46),
            SizedBox(height: 12),
            Text('No products found'),
          ],
        ),
      ),
    );
  }
}
