import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../categories/models/category_model.dart';
import '../../products/models/product_image_upload.dart';
import '../../products/models/product_model.dart';

class ProductFormData {
  final String name;
  final String description;
  final double price;
  final double? discountPrice;
  final String categoryId;
  final int stock;
  final String unitType;
  final String unitLabel;
  final int? maxOrderQty;
  final bool isActive;
  final List<String> existingImageUrls;
  final List<ProductImageUpload> newImages;

  const ProductFormData({
    required this.name,
    required this.description,
    required this.price,
    required this.discountPrice,
    required this.categoryId,
    required this.stock,
    required this.unitType,
    required this.unitLabel,
    required this.maxOrderQty,
    required this.isActive,
    required this.existingImageUrls,
    required this.newImages,
  });
}

class ProductForm extends StatefulWidget {
  final ProductModel? initialProduct;
  final List<CategoryModel> categories;
  final bool isSaving;
  final ValueChanged<ProductFormData> onSubmit;
  final VoidCallback? onCancel;

  const ProductForm({
    super.key,
    this.initialProduct,
    required this.categories,
    required this.isSaving,
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  static const int _targetImageBytes = 200 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _discountPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _unitController;
  late final TextEditingController _unitLabelController;
  late final TextEditingController _maxOrderQtyController;

  late bool _isActive;
  String? _categoryId;
  late List<String> _existingImages;
  final List<ProductImageUpload> _newImages = [];
  bool _isCompressing = false;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    final product = widget.initialProduct;
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController =
        TextEditingController(text: product?.description ?? '');
    _priceController =
        TextEditingController(text: product?.price.toStringAsFixed(2) ?? '');
    _discountPriceController = TextEditingController(
      text: product?.discountPrice?.toStringAsFixed(2) ?? '',
    );
    _stockController =
        TextEditingController(text: product?.stock.toString() ?? '');
    _unitController = TextEditingController(text: product?.unitType ?? '');
    _unitLabelController = TextEditingController(text: product?.unitLabel ?? '');
    _maxOrderQtyController =
        TextEditingController(text: product?.maxOrderQty?.toString() ?? '');
    _isActive = product?.isActive ?? true;
    _categoryId = product?.categoryId;
    _existingImages = [...?product?.images];

    if (_categoryId == null && widget.categories.isNotEmpty) {
      _categoryId = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _unitLabelController.dispose();
    _maxOrderQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            context,
            title: 'Product Details',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final fields = [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                      prefixIcon: Icon(Icons.shopping_basket_outlined),
                    ),
                    validator: _required,
                  ),
                  DropdownButtonFormField<String>(
                    value: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      for (final category in widget.categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: widget.categories.isEmpty
                        ? null
                        : (value) => setState(() => _categoryId = value),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Select a category'
                        : null,
                  ),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Base price',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _positiveNumber,
                  ),
                  TextFormField(
                    controller: _discountPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Discount price',
                      prefixIcon: Icon(Icons.local_offer_outlined),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _optionalPositiveNumber,
                  ),
                  TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: _wholeNumber,
                  ),
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit type (size)',
                      hintText: '500ml, 1kg, 250g, pack',
                      prefixIcon: Icon(Icons.straighten),
                      helperText: 'e.g., 500ml, 1kg',
                    ),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _unitLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Unit label',
                      hintText: 'kg, piece, litre, dozen, packet',
                      prefixIcon: Icon(Icons.label_outline),
                      helperText: 'Standardized unit: kg, piece, litre, etc.',
                    ),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _maxOrderQtyController,
                    decoration: const InputDecoration(
                      labelText: 'Max order quantity (optional)',
                      hintText: 'Leave empty for unlimited',
                      prefixIcon: Icon(Icons.shopping_cart_outlined),
                      helperText: 'Maximum units per customer per order',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ];

                if (!isWide) {
                  return Column(
                    children: [
                      for (final field in fields) ...[
                        field,
                        const SizedBox(height: 14),
                      ],
                    ],
                  );
                }

                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final field in fields)
                      SizedBox(
                          width: (constraints.maxWidth - 14) / 2, child: field),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _buildSection(
            context,
            title: 'Description',
            child: TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
              validator: _required,
            ),
          ),
          const SizedBox(height: 18),
          _buildSection(
            context,
            title: 'Images',
            trailing: TextButton.icon(
              onPressed: widget.isSaving || _isCompressing
                  ? null
                  : _pickAndCompressImages,
              icon: _isCompressing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_isCompressing ? 'Compressing' : 'Add Images'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_imageError != null) ...[
                  Text(
                    _imageError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_existingImages.isEmpty && _newImages.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.orangePale,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text(
                      'Add at least one product image. Images are compressed under 200KB before upload.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final imageUrl in _existingImages)
                        _ImagePreview(
                          imageUrl: imageUrl,
                          label: 'Saved',
                          onRemove: () {
                            setState(() => _existingImages.remove(imageUrl));
                          },
                        ),
                      for (final image in _newImages)
                        _ImagePreview(
                          imageBytes: image.bytes,
                          label: '${image.sizeInKb}KB',
                          onRemove: () {
                            setState(() => _newImages.remove(image));
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            value: _isActive,
            onChanged: widget.isSaving
                ? null
                : (value) => setState(() => _isActive = value),
            title: const Text('Product active'),
            subtitle:
                const Text('Inactive products are hidden from customers.'),
            activeColor: AppColors.success,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (widget.onCancel != null)
                OutlinedButton.icon(
                  onPressed: widget.isSaving ? null : widget.onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: widget.isSaving || _isCompressing ? null : _submit,
                icon: widget.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(widget.isSaving ? 'Saving' : 'Save Product'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Future<void> _pickAndCompressImages() async {
    setState(() {
      _isCompressing = true;
      _imageError = null;
    });

    try {
      final picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;

      for (final image in picked) {
        final compressed = await _compressImage(image);
        _newImages.add(compressed);
      }
    } catch (e) {
      _imageError = 'Could not prepare image: $e';
    } finally {
      if (mounted) {
        setState(() => _isCompressing = false);
      }
    }
  }

  Future<ProductImageUpload> _compressImage(XFile image) async {
    final originalBytes = await image.readAsBytes();
    Uint8List bestBytes = originalBytes;

    for (final quality in [85, 75, 65, 55, 45, 35, 25]) {
      final result = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 1280,
        minHeight: 1280,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      bestBytes = Uint8List.fromList(result);
      if (bestBytes.length <= _targetImageBytes) break;
    }

    return ProductImageUpload(
      fileName: '${DateTime.now().microsecondsSinceEpoch}_${image.name}.jpg',
      bytes: bestBytes,
      contentType: 'image/jpeg',
    );
  }

  void _submit() {
    setState(() => _imageError = null);

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_existingImages.isEmpty && _newImages.isEmpty) {
      setState(() => _imageError = 'Add at least one product image.');
      return;
    }

    final price = double.parse(_priceController.text.trim());
    final discountText = _discountPriceController.text.trim();
    final discountPrice =
        discountText.isEmpty ? null : double.parse(discountText);

    if (discountPrice != null && discountPrice >= price) {
      setState(
          () => _imageError = 'Discount price must be lower than base price.');
      return;
    }

    widget.onSubmit(
      ProductFormData(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        discountPrice: discountPrice,
        categoryId: _categoryId!,
        stock: int.parse(_stockController.text.trim()),
        unitType: _unitController.text.trim(),
        unitLabel: _unitLabelController.text.trim(),
        maxOrderQty: _maxOrderQtyController.text.trim().isEmpty
            ? null
            : int.tryParse(_maxOrderQtyController.text.trim()),
        isActive: _isActive,
        existingImageUrls: List.unmodifiable(_existingImages),
        newImages: List.unmodifiable(_newImages),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _positiveNumber(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
    return null;
  }

  String? _optionalPositiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
    return null;
  }

  String? _wholeNumber(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) return 'Enter a valid stock';
    return null;
  }
}

class _ImagePreview extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String label;
  final VoidCallback onRemove;

  const _ImagePreview({
    this.imageUrl,
    this.imageBytes,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 132,
          height: 132,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.orangePale,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: imageBytes != null
              ? Image.memory(imageBytes!, fit: BoxFit.cover)
              : Image.network(imageUrl!, fit: BoxFit.cover),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.62),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton.filled(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              fixedSize: const Size(32, 32),
            ),
          ),
        ),
      ],
    );
  }
}
