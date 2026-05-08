import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';
import 'dart:io';

/// Admin Categories Screen
/// 
/// Allows admins to:
/// - View all categories
/// - Create new categories with image upload
/// - Edit existing categories
/// - Delete categories
/// - Reorder categories

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final CategoryService _categoryService = CategoryService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            '📂 Manage Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          centerTitle: true,
        ),
        body: StreamBuilder(
          stream: _categoryService.watchCategories(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            final categories = snapshot.data ?? [];

            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                // Add button at the end
                if (index == categories.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddCategoryDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add New Category',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                final category = categories[index];

                return _CategoryListItem(
                  category: category,
                  onEdit: () => _showEditCategoryDialog(context, category),
                  onDelete: () => _deleteCategory(context, category),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CategoryFormDialog(
        categoryService: _categoryService,
        imagePicker: _imagePicker,
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => _CategoryFormDialog(
        categoryService: _categoryService,
        imagePicker: _imagePicker,
        category: category,
      ),
    );
  }

  void _deleteCategory(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _categoryService.deleteCategory(category.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '✅ Category deleted'
                          : '❌ Failed to delete category',
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Category Form Dialog
// ============================================================================

class _CategoryFormDialog extends StatefulWidget {
  final CategoryService categoryService;
  final ImagePicker imagePicker;
  final CategoryModel? category;

  const _CategoryFormDialog({
    required this.categoryService,
    required this.imagePicker,
    this.category,
  });

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;
  late TextEditingController _sortOrderController;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.category?.description ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.category?.imageUrl ?? '',
    );
    _sortOrderController = TextEditingController(
      text: widget.category?.sortOrder.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await widget.imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter category name')),
      );
      return;
    }

    if (_imageUrlController.text.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an image URL or upload an image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageUrl = _selectedImage != null
          ? _selectedImage!.path
          : _imageUrlController.text;

      if (widget.category != null) {
        // Edit existing category
        await widget.categoryService.updateCategory(
          categoryId: widget.category!.id,
          name: _nameController.text,
          description: _descriptionController.text,
          imageUrl: imageUrl,
          sortOrder: int.tryParse(_sortOrderController.text) ?? 0,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Category updated')),
          );
        }
      } else {
        // Create new category
        await widget.categoryService.createCategory(
          name: _nameController.text,
          description: _descriptionController.text,
          imageUrl: imageUrl,
          sortOrder: int.tryParse(_sortOrderController.text) ?? 0,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Category created')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.category != null ? 'Edit Category' : 'Add New Category',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),

              // Name
              _buildTextField(
                controller: _nameController,
                label: 'Category Name',
                hint: 'e.g., Personal Care',
              ),
              const SizedBox(height: 16),

              // Description
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Short description',
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Image URL
              _buildTextField(
                controller: _imageUrlController,
                label: 'Image URL',
                hint: 'https://example.com/image.jpg',
              ),
              const SizedBox(height: 12),

              // Pick image button
              Center(
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: Text(
                    _selectedImage != null
                        ? 'Image selected ✓'
                        : 'Or pick from gallery',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sort Order
              _buildTextField(
                controller: _sortOrderController,
                label: 'Sort Order',
                hint: '0',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      disabledBackgroundColor: Colors.grey[400],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(color: Colors.white),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          minLines: 1,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.grey,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.orange,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Category List Item
// ============================================================================

class _CategoryListItem extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryListItem({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                category.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sort: ${category.sortOrder}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: onEdit,
                  child: const Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  onTap: onDelete,
                  child: const Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
