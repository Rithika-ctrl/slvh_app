import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../categories/models/category_model.dart';
import '../../categories/services/category_service.dart';
import '../../products/models/product_model.dart';
import '../../products/services/cloudinary_upload_service.dart';
import '../../products/services/product_service.dart';
import '../widgets/product_form.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final ProductModel? initialProduct;

  const EditProductScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _categoryService = CategoryService();
  final _productService = ProductService();
  final _cloudinaryService = CloudinaryUploadService();
  late final Future<_EditProductPayload> _payloadFuture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _payloadFuture = _loadPayload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('Edit Product'),
        centerTitle: false,
      ),
      body: FutureBuilder<_EditProductPayload>(
        future: _payloadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Could not load product: ${snapshot.error}'));
          }

          final payload = snapshot.data;
          if (payload == null || payload.product == null) {
            return const Center(child: Text('Product not found'));
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ProductForm(
                  initialProduct: payload.product,
                  categories: payload.categories,
                  isSaving: _isSaving,
                  onCancel: () => context.pop(),
                  onSubmit: _updateProduct,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<_EditProductPayload> _loadPayload() async {
    final results = await Future.wait([
      _categoryService.getAllCategories(),
      widget.initialProduct == null
          ? _productService.getProductById(widget.productId)
          : Future<ProductModel?>.value(widget.initialProduct),
    ]);

    return _EditProductPayload(
      categories: results[0] as List<CategoryModel>,
      product: results[1] as ProductModel?,
    );
  }

  Future<void> _updateProduct(ProductFormData data) async {
    setState(() => _isSaving = true);

    try {
      final uploadedImages = await _cloudinaryService.uploadProductImages(
        productId: widget.productId,
        images: data.newImages,
      );
      final imageUrls = [
        ...data.existingImageUrls,
        ...uploadedImages.map((asset) => asset.secureUrl),
      ];

      await _firestore.collection('products').doc(widget.productId).update({
        'name': data.name,
        'name_lowercase': data.name.toLowerCase(),
        'description': data.description,
        'price': data.price,
        'discountPrice': data.discountPrice,
        'images': [...data.existingImageUrls, ...imageUrls],
        'categoryId': data.categoryId,
        'stock': data.stock,
        'unitType': data.unitType,
        'unit_label': data.unitLabel,
        'max_order_qty': data.maxOrderQty,
        'isActive': data.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update product: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _EditProductPayload {
  final List<CategoryModel> categories;
  final ProductModel? product;

  const _EditProductPayload({
    required this.categories,
    required this.product,
  });
}
