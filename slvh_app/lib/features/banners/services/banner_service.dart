/// BannerService
///
/// Handles all Firestore and Firebase Storage operations for promotional
/// banners. Collection path: `banners/`.
///
/// Storage path: `banners/<uuid>.<ext>`

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

import '../models/banner_model.dart';

class BannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _collection = 'banners';
  static const String _storageFolder = 'banners';

  // ── Streams ───────────────────────────────────────────────────────────────

  /// All banners ordered by [sortOrder] – for admin use.
  Stream<List<BannerModel>> watchAllBanners() {
    return _firestore
        .collection(_collection)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BannerModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Only active banners ordered by [sortOrder] – for customer carousel.
  Stream<List<BannerModel>> watchActiveBanners() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BannerModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Upload [imageFile] to Firebase Storage and create a banner document.
  ///
  /// Returns the newly created [BannerModel].
  Future<BannerModel> addBanner({
    required File imageFile,
    String? deeplink,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final imageUrl =
        await _uploadImage(imageFile);

    final now = DateTime.now();
    final docRef = _firestore.collection(_collection).doc();

    final banner = BannerModel(
      id: docRef.id,
      imageUrl: imageUrl,
      deeplink: deeplink?.isNotEmpty == true ? deeplink : null,
      isActive: isActive,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(banner.toFirestore());
    return banner;
  }

  /// Update metadata of an existing banner (does NOT re-upload the image).
  Future<void> updateBanner({
    required String bannerId,
    String? deeplink,
    bool? isActive,
    int? sortOrder,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (deeplink != null) updates['deeplink'] = deeplink.isNotEmpty ? deeplink : null;
    if (isActive != null) updates['isActive'] = isActive;
    if (sortOrder != null) updates['sortOrder'] = sortOrder;

    await _firestore
        .collection(_collection)
        .doc(bannerId)
        .update(updates);
  }

  /// Toggle [isActive] on a banner.
  Future<void> toggleActive(String bannerId, {required bool active}) async {
    await _firestore.collection(_collection).doc(bannerId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a banner document and its Storage file.
  Future<void> deleteBanner(BannerModel banner) async {
    // Remove Firestore doc
    await _firestore.collection(_collection).doc(banner.id).delete();

    // Remove Storage file – best-effort (no crash if file is already gone)
    try {
      await _storage.refFromURL(banner.imageUrl).delete();
    } catch (_) {}
  }

  /// Re-order banners by writing new [sortOrder] values in a batch.
  Future<void> reorder(List<BannerModel> ordered) async {
    final batch = _firestore.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(
        _firestore.collection(_collection).doc(ordered[i].id),
        {
          'sortOrder': i,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Compress and upload an image, returning the download URL.
  Future<String> _uploadImage(File imageFile) async {
    final uuid = const Uuid().v4();
    final ext = imageFile.path.split('.').last.toLowerCase();
    final storagePath = '$_storageFolder/$uuid.$ext';

    File fileToUpload = imageFile;

    // Compress on mobile only
    if (!kIsWeb) {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        '${imageFile.parent.path}/${uuid}_compressed.$ext',
        quality: 75,
        minWidth: 1280,
        minHeight: 480,
      );
      if (compressed != null) {
        fileToUpload = File(compressed.path);
      }
    }

    final ref = _storage.ref().child(storagePath);
    await ref.putFile(fileToUpload);
    return await ref.getDownloadURL();
  }
}