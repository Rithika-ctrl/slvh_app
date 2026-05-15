import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

/// Handles all Firestore operations for product reviews.
///
/// Collections touched:
///   reviews/{review_id}         — individual review documents
///   products/{product_id}       — avg_rating + reviewCount denormalized fields
///   orders/{order_id}           — rated_product_ids[] to track which products
///                                 the customer has already reviewed on an order
class ReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Submit / update review ───────────────────────────────────────────────

  /// Writes a new review and recalculates the product's avg_rating.
  ///
  /// One review per (user_id + product_id + order_id) is enforced by query.
  /// If the user already reviewed this product for this order it updates it.
  Future<void> submitReview({
    required String productId,
    required String userId,
    required String orderId,
    required double rating,
    String comment = '',
  }) async {
    // Check if review already exists for this order+product
    final existing = await _db
        .collection('reviews')
        .where('product_id', isEqualTo: productId)
        .where('user_id', isEqualTo: userId)
        .where('order_id', isEqualTo: orderId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Update existing
      await existing.docs.first.reference.update({
        'rating': rating,
        'comment': comment,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new
      await _db.collection('reviews').add({
        'product_id': productId,
        'user_id': userId,
        'order_id': orderId,
        'rating': rating,
        'comment': comment,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': null,
      });

      // Mark product as reviewed on this order so the dialog doesn't re-show
      await _db.collection('orders').doc(orderId).update({
        'rated_product_ids': FieldValue.arrayUnion([productId]),
      });
    }

    // Recalculate and denormalize avg_rating onto the product document
    await _recalcAvgRating(productId);
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Stream of all reviews for a product, newest first.
  Stream<List<ReviewModel>> watchProductReviews(String productId) {
    return _db
        .collection('reviews')
        .where('product_id', isEqualTo: productId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReviewModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Returns a single review by a user for a specific order+product, or null.
  Future<ReviewModel?> getExistingReview({
    required String productId,
    required String userId,
    required String orderId,
  }) async {
    final snap = await _db
        .collection('reviews')
        .where('product_id', isEqualTo: productId)
        .where('user_id', isEqualTo: userId)
        .where('order_id', isEqualTo: orderId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ReviewModel.fromFirestore(
        snap.docs.first.id, snap.docs.first.data());
  }

  /// Returns the list of product IDs the customer has already rated for
  /// a given order (stored as rated_product_ids[] on the order doc).
  Future<List<String>> getRatedProductIds(String orderId) async {
    final snap = await _db.collection('orders').doc(orderId).get();
    final data = snap.data();
    if (data == null) return [];
    return List<String>.from(data['rated_product_ids'] as List? ?? []);
  }

  // ── Avg rating recalculation ─────────────────────────────────────────────

  /// Recomputes avg_rating and reviewCount on products/{productId}.
  ///
  /// Called after every submit. For scale, replace with a Cloud Function
  /// triggered on reviews/{id} onCreate / onUpdate.
  Future<void> _recalcAvgRating(String productId) async {
    final snap = await _db
        .collection('reviews')
        .where('product_id', isEqualTo: productId)
        .get();

    if (snap.docs.isEmpty) {
      await _db.collection('products').doc(productId).update({
        'rating': null,
        'reviewCount': 0,
      });
      return;
    }

    final ratings = snap.docs
        .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
        .toList();

    final avg = ratings.reduce((a, b) => a + b) / ratings.length;

    await _db.collection('products').doc(productId).update({
      'rating': double.parse(avg.toStringAsFixed(1)),
      'reviewCount': ratings.length,
    });
  }
}