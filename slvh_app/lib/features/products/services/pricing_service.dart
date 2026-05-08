import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/products/models/pricing_tier_model.dart';

/// Service for managing pricing tiers in Firestore
/// Pricing tiers are stored as sub-collections under products/{productId}/pricing_tiers/
class PricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all pricing tiers for a product
  Future<List<PricingTierModel>> getPricingTiers(String productId) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('pricing_tiers')
          .orderBy('quantity', descending: false)
          .get();

      final tiers = snapshot.docs
          .map((doc) => PricingTierModel.fromFirestore(doc.id, doc.data()))
          .toList();

      return tiers;
    } catch (e) {
      print('Error fetching pricing tiers: $e');
      return [];
    }
  }

  /// Watch pricing tiers in real-time
  Stream<List<PricingTierModel>> watchPricingTiers(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .collection('pricing_tiers')
        .orderBy('quantity', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PricingTierModel.fromFirestore(doc.id, doc.data()))
            .toList())
        .handleError((e) {
          print('Error watching pricing tiers: $e');
          return [];
        });
  }

  /// Get a specific pricing tier
  Future<PricingTierModel?> getPricingTier(
    String productId,
    String tierId,
  ) async {
    try {
      final doc = await _firestore
          .collection('products')
          .doc(productId)
          .collection('pricing_tiers')
          .doc(tierId)
          .get();

      if (!doc.exists) return null;
      return PricingTierModel.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      print('Error fetching pricing tier: $e');
      return null;
    }
  }

  /// Create a new pricing tier
  Future<void> createPricingTier(
    String productId,
    PricingTierModel tier,
  ) async {
    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('pricing_tiers')
          .add({
        ...tier.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Pricing tier created');
    } catch (e) {
      print('Error creating pricing tier: $e');
      rethrow;
    }
  }

  /// Update an existing pricing tier
  Future<void> updatePricingTier(
    String productId,
    String tierId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('pricing_tiers')
          .doc(tierId)
          .update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Pricing tier updated');
    } catch (e) {
      print('Error updating pricing tier: $e');
      rethrow;
    }
  }

  /// Delete a pricing tier
  Future<void> deletePricingTier(String productId, String tierId) async {
    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('pricing_tiers')
          .doc(tierId)
          .delete();
      print('✅ Pricing tier deleted');
    } catch (e) {
      print('Error deleting pricing tier: $e');
      rethrow;
    }
  }

  /// Set a pricing tier as default
  Future<void> setDefaultTier(String productId, String tierId) async {
    try {
      final batch = _firestore.batch();

      // Get all current tiers
      final tiers = await getPricingTiers(productId);

      // Unset all as default
      for (var tier in tiers) {
        batch.update(
          _firestore
              .collection('products')
              .doc(productId)
              .collection('pricing_tiers')
              .doc(tier.id),
          {'isDefault': false},
        );
      }

      // Set selected tier as default
      batch.update(
        _firestore
            .collection('products')
            .doc(productId)
            .collection('pricing_tiers')
            .doc(tierId),
        {'isDefault': true},
      );

      await batch.commit();
      print('✅ Default tier updated');
    } catch (e) {
      print('Error setting default tier: $e');
      rethrow;
    }
  }

  /// Bulk create pricing tiers
  Future<void> bulkCreatePricingTiers(
    String productId,
    List<PricingTierModel> tiers,
  ) async {
    try {
      final batch = _firestore.batch();

      for (var tier in tiers) {
        batch.set(
          _firestore
              .collection('products')
              .doc(productId)
              .collection('pricing_tiers')
              .doc(),
          {
            ...tier.toFirestore(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();
      print('✅ ${tiers.length} pricing tiers created');
    } catch (e) {
      print('Error bulk creating pricing tiers: $e');
      rethrow;
    }
  }

  /// Get best value tier (highest savings percentage)
  Future<PricingTierModel?> getBestValueTier(
    String productId,
    double basePrice,
  ) async {
    try {
      final tiers = await getPricingTiers(productId);
      if (tiers.isEmpty) return null;

      tiers.sort((a, b) {
        final savingsA = a.calculateSavings(basePrice);
        final savingsB = b.calculateSavings(basePrice);
        return savingsB.compareTo(savingsA); // Descending order
      });

      return tiers.first;
    } catch (e) {
      print('Error getting best value tier: $e');
      return null;
    }
  }

  /// Delete all pricing tiers for a product
  Future<void> deleteAllPricingTiers(String productId) async {
    try {
      final tiers = await getPricingTiers(productId);
      final batch = _firestore.batch();

      for (var tier in tiers) {
        batch.delete(
          _firestore
              .collection('products')
              .doc(productId)
              .collection('pricing_tiers')
              .doc(tier.id),
        );
      }

      await batch.commit();
      print('✅ All pricing tiers deleted');
    } catch (e) {
      print('Error deleting all pricing tiers: $e');
      rethrow;
    }
  }
}
