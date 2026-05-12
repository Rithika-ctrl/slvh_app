import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../categories/models/category_model.dart';
import '../../categories/services/category_service.dart';
import '../widgets/product_form.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _categoryService = CategoryService();
  late final Future<List<CategoryModel>> _categoriesFuture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _categoryService.getAllCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('Add Product'),
        centerTitle: false,
      ),
      body: FutureBuilder<List<CategoryModel>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Could not load categories: ${snapshot.error}'));
          }

          final categories = snapshot.data ?? const [];
          if (categories.isEmpty) {
            return const Center(
              child:
                  Text('Create at least one category before adding products.'),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ProductForm(
                  categories: categories,
                  isSaving: _isSaving,
                  onCancel: () => context.pop(),
                  onSubmit: _createProduct,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createProduct(ProductFormData data) async {
    setState(() => _isSaving = true);

    try {
      final productRef = _firestore.collection('products').doc();
      final imageUrls = await _uploadImages(productRef.id, data.newImages);

      await productRef.set({
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
        'rating': null,
        'reviewCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product created successfully')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create product: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<List<String>> _uploadImages(
    String productId,
    List<ProductImageUpload> images,
  ) async {
    final urls = <String>[];

    for (final image in images) {
      final ref = _storage
          .ref()
          .child('product-images')
          .child(productId)
          .child(image.fileName);

      await ref.putData(
        image.bytes,
        SettableMetadata(contentType: image.contentType),
      );
      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }
}
