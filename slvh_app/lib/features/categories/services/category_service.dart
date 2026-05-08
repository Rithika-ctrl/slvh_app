import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

/// Category Service
/// 
/// Handles all Firestore operations for categories:
/// - Fetch all categories (sorted by sortOrder)
/// - Fetch single category
/// - Create new category (admin)
/// - Update category (admin)
/// - Delete category (admin)

class CategoryService {
  static const String _collectionPath = 'categories';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============= PUBLIC METHODS =============

  /// Fetch all categories sorted by sortOrder
  /// Returns empty list if no categories found
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .orderBy('sortOrder', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  /// Fetch a single category by ID
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    try {
      final doc = await _firestore.collection(_collectionPath).doc(categoryId).get();

      if (doc.exists) {
        return CategoryModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error fetching category: $e');
      return null;
    }
  }

  /// Create a new category (admin only)
  /// Returns the category ID if successful
  Future<String?> createCategory({
    required String name,
    required String description,
    required String imageUrl,
    required int sortOrder,
  }) async {
    try {
      final docRef = await _firestore.collection(_collectionPath).add({
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'sortOrder': sortOrder,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Category created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating category: $e');
      return null;
    }
  }

  /// Update an existing category (admin only)
  Future<bool> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    String? imageUrl,
    int? sortOrder,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (imageUrl != null) updateData['imageUrl'] = imageUrl;
      if (sortOrder != null) updateData['sortOrder'] = sortOrder;

      await _firestore.collection(_collectionPath).doc(categoryId).update(updateData);

      print('Category $categoryId updated');
      return true;
    } catch (e) {
      print('Error updating category: $e');
      return false;
    }
  }

  /// Delete a category (admin only)
  Future<bool> deleteCategory(String categoryId) async {
    try {
      await _firestore.collection(_collectionPath).doc(categoryId).delete();

      print('Category $categoryId deleted');
      return true;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }

  /// Watch all categories in real-time
  /// Returns a stream that updates whenever categories change
  Stream<List<CategoryModel>> watchCategories() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('sortOrder', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CategoryModel.fromFirestore(doc.id, doc.data()))
              .toList();
        })
        .handleError((error) {
          print('Error watching categories: $error');
          return <CategoryModel>[];
        });
  }

  /// Batch update sort order (for admin reordering)
  Future<bool> updateSortOrder(Map<String, int> categoryIdToSortOrder) async {
    try {
      final batch = _firestore.batch();

      categoryIdToSortOrder.forEach((categoryId, sortOrder) {
        batch.update(
          _firestore.collection(_collectionPath).doc(categoryId),
          {
            'sortOrder': sortOrder,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      await batch.commit();
      print('Sort order updated for ${categoryIdToSortOrder.length} categories');
      return true;
    } catch (e) {
      print('Error updating sort order: $e');
      return false;
    }
  }

  /// Get category count
  Future<int> getCategoryCount() async {
    try {
      final snapshot = await _firestore.collection(_collectionPath).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting category count: $e');
      return 0;
    }
  }
}
