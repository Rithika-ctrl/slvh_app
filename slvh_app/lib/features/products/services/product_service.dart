import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

/// Product Service
///
/// Handles all Firestore operations for products:
/// - Fetch all products
/// - Fetch by category with real-time updates
/// - Search products
/// - Filter by stock status
/// - Watch single product for real-time stock updates
/// - Admin CRUD operations

class ProductService {
  static const String _collectionPath = 'products';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============= PUBLIC METHODS =============

  /// Fetch all active products
  Future<List<ProductModel>> getAllProducts({
    bool onlyActive = true,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(_collectionPath);

      if (onlyActive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  /// Fetch a single product by ID with real-time updates
  Stream<ProductModel?> watchProduct(String productId) {
    return _firestore
        .collection(_collectionPath)
        .doc(productId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return ProductModel.fromFirestore(
          snapshot.id,
          snapshot.data() as Map<String, dynamic>,
        );
      }
      return null;
    }).handleError((error) {
      print('Error watching product: $error');
      return null;
    });
  }

  /// Fetch product by ID (one-time)
  Future<ProductModel?> getProductById(String productId) async {
    try {
      final doc =
          await _firestore.collection(_collectionPath).doc(productId).get();

      if (doc.exists) {
        return ProductModel.fromFirestore(
            doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error fetching product: $e');
      return null;
    }
  }

  /// Get products by category ID
  /// Returns stream for real-time updates
  Stream<List<ProductModel>> watchProductsByCategory(String categoryId) {
    return _firestore
        .collection(_collectionPath)
        .where('categoryId', isEqualTo: categoryId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    }).handleError((error) {
      print('Error watching products by category: $error');
      return <ProductModel>[];
    });
  }

  /// Search products by name (case-insensitive, prefix matching)
  /// Uses name_lowercase field for efficient Firestore querying
  /// Requires Firestore index on name_lowercase ASC
  Stream<List<ProductModel>> searchProductsOptimized(String query) {
    if (query.isEmpty) {
      return watchAllProducts();
    }

    final queryLower = query.toLowerCase();
    final nextChar = String.fromCharCode(queryLower.codeUnitAt(queryLower.length - 1) + 1);
    final endValue = queryLower.substring(0, queryLower.length - 1) + nextChar;

    return _firestore
        .collection(_collectionPath)
        .where('isActive', isEqualTo: true)
        .where('name_lowercase', isGreaterThanOrEqualTo: queryLower)
        .where('name_lowercase', isLessThan: endValue)
        .orderBy('name_lowercase')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    }).handleError((error) {
      print('Error searching products: $error');
      return <ProductModel>[];
    });
  }

  /// Search products by category with optimized name search
  Stream<List<ProductModel>> searchProductsByCategoryOptimized({
    required String categoryId,
    required String searchQuery,
  }) {
    if (searchQuery.isEmpty) {
      return watchProductsByCategory(categoryId);
    }

    final queryLower = searchQuery.toLowerCase();
    final nextChar = String.fromCharCode(queryLower.codeUnitAt(queryLower.length - 1) + 1);
    final endValue = queryLower.substring(0, queryLower.length - 1) + nextChar;

    return _firestore
        .collection(_collectionPath)
        .where('categoryId', isEqualTo: categoryId)
        .where('isActive', isEqualTo: true)
        .where('name_lowercase', isGreaterThanOrEqualTo: queryLower)
        .where('name_lowercase', isLessThan: endValue)
        .orderBy('name_lowercase')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    }).handleError((error) {
      print('Error searching products by category: $error');
      return <ProductModel>[];
    });
  }

  /// Search products by name or description (fallback method)
  /// Implements basic search (case-insensitive prefix matching)
  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      if (query.isEmpty) {
        return getAllProducts();
      }

      final queryLower = query.toLowerCase();

      // Firestore doesn't support full text search, so we fetch all and filter
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('isActive', isEqualTo: true)
          .get();

      final results = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .where((product) =>
              product.name.toLowerCase().contains(queryLower) ||
              product.description.toLowerCase().contains(queryLower))
          .toList();

      return results;
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }

  /// Stream products by category with search
  Stream<List<ProductModel>> searchProductsByCategory({
    required String categoryId,
    required String searchQuery,
  }) {
    return _firestore
        .collection(_collectionPath)
        .where('categoryId', isEqualTo: categoryId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();

      if (searchQuery.isEmpty) {
        return products;
      }

      final queryLower = searchQuery.toLowerCase();
      return products
          .where((product) =>
              product.name.toLowerCase().contains(queryLower) ||
              product.description.toLowerCase().contains(queryLower))
          .toList();
    }).handleError((error) {
      print('Error searching products by category: $error');
      return <ProductModel>[];
    });
  }

  /// Get products with discount
  Future<List<ProductModel>> getDiscountedProducts() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('isActive', isEqualTo: true)
          .where('discountPrice', isNotEqualTo: null)
          .get();

      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching discounted products: $e');
      return [];
    }
  }

  /// Get in-stock products
  Future<List<ProductModel>> getInStockProducts() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('isActive', isEqualTo: true)
          .where('stock', isGreaterThan: 0)
          .get();

      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching in-stock products: $e');
      return [];
    }
  }

  /// Watch all products in real-time
  Stream<List<ProductModel>> watchAllProducts({bool onlyActive = true}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true);

    if (onlyActive) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    }).handleError((error) {
      print('Error watching all products: $error');
      return <ProductModel>[];
    });
  }

  // ============= ADMIN METHODS =============

  /// Create a new product (admin only)
  Future<String?> createProduct({
    required String name,
    required String description,
    required double price,
    double? discountPrice,
    required List<String> images,
    required String categoryId,
    required int stock,
    required String unitType,
  }) async {
    try {
      final docRef = await _firestore.collection(_collectionPath).add({
        'name': name,
        'name_lowercase': name.toLowerCase(),
        'description': description,
        'price': price,
        'discountPrice': discountPrice,
        'images': images,
        'categoryId': categoryId,
        'stock': stock,
        'unitType': unitType,
        'isActive': true,
        'rating': null,
        'reviewCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Product created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating product: $e');
      return null;
    }
  }

  /// Update an existing product (admin only)
  Future<bool> updateProduct({
    required String productId,
    String? name,
    String? description,
    double? price,
    double? discountPrice,
    List<String>? images,
    String? categoryId,
    int? stock,
    String? unitType,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) {
        updateData['name'] = name;
        updateData['name_lowercase'] = name.toLowerCase();
      }
      if (description != null) updateData['description'] = description;
      if (price != null) updateData['price'] = price;
      if (discountPrice != null) updateData['discountPrice'] = discountPrice;
      if (images != null) updateData['images'] = images;
      if (categoryId != null) updateData['categoryId'] = categoryId;
      if (stock != null) updateData['stock'] = stock;
      if (unitType != null) updateData['unitType'] = unitType;
      if (isActive != null) updateData['isActive'] = isActive;

      await _firestore
          .collection(_collectionPath)
          .doc(productId)
          .update(updateData);

      print('Product $productId updated');
      return true;
    } catch (e) {
      print('Error updating product: $e');
      return false;
    }
  }

  /// Update product stock (for cart operations)
  Future<bool> updateStock({
    required String productId,
    required int newStock,
  }) async {
    try {
      await _firestore.collection(_collectionPath).doc(productId).update({
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Stock updated for product $productId: $newStock');
      return true;
    } catch (e) {
      print('Error updating stock: $e');
      return false;
    }
  }

  /// Delete a product (admin only)
  Future<bool> deleteProduct(String productId) async {
    try {
      await _firestore.collection(_collectionPath).doc(productId).delete();

      print('Product $productId deleted');
      return true;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }

  /// Get product count
  Future<int> getProductCount({bool onlyActive = true}) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(_collectionPath);

      if (onlyActive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting product count: $e');
      return 0;
    }
  }
}
