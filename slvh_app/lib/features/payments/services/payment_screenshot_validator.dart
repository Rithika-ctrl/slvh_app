import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/secure_logger.dart';

/// Validation rules for payment screenshots
class PaymentScreenshotValidator {
  // Allowed file extensions (case-insensitive)
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png'];

  // Maximum file size in bytes: 5 MB
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

  // Minimum file size to consider (1 KB - prevent empty files)
  static const int minFileSizeBytes = 1 * 1024; // 1 KB

  /// Validate screenshot file
  /// Checks extension, file size, and file existence
  /// Returns: (isValid, errorMessage)
  static Future<(bool, String?)> validateScreenshot(File file) async {
    try {
      // Check if file exists
      if (!await file.exists()) {
        return (false, 'File does not exist');
      }

      // Get file extension
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();

      // Validate extension
      if (!allowedExtensions.contains(extension)) {
        return (
          false,
          'Invalid file format. Only JPG and PNG are allowed.\nSelected: .$extension'
        );
      }

      // Get file size
      final fileSizeBytes = await file.length();

      // Check minimum size
      if (fileSizeBytes < minFileSizeBytes) {
        return (false, 'File is too small. Please select a valid image.');
      }

      // Check maximum size (before compression)
      if (fileSizeBytes > maxFileSizeBytes) {
        return (
          false,
          'File is too large (${_formatBytes(fileSizeBytes)}). Maximum size is 5 MB.\n\nTry: Compress the image or take a screenshot instead.'
        );
      }

      return (true, null);
    } catch (e) {
      return (false, 'Error validating file: $e');
    }
  }

  /// Compress image file
  /// Reduces file size while maintaining reasonable quality
  /// Returns compressed file or original if compression fails
  static Future<File> compressImage(File file) async {
    try {
      final fileSizeBytes = await file.length();

      // If already under 2 MB, minimal compression needed
      if (fileSizeBytes < 2 * 1024 * 1024) {
        AppLogger.debug('✅ Image already optimized (${_formatBytes(fileSizeBytes)})');
        return file;
      }

      AppLogger.debug('🔄 Compressing image (${_formatBytes(fileSizeBytes)})...');

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final compressedPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Compress image
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        compressedPath,
        quality: 70, // 70% quality for good balance
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        AppLogger.debug('⚠️ Compression failed, using original');
        return file;
      }

      final compressedFile = File(result.path);
      final compressedSizeBytes = await compressedFile.length();

      AppLogger.debug('✅ Image compressed: ${_formatBytes(fileSizeBytes)} → ${_formatBytes(compressedSizeBytes)}');

      // Check if compressed file exceeds max size
      if (compressedSizeBytes > maxFileSizeBytes) {
        AppLogger.debug('⚠️ Compressed image still too large, trying lower quality...');
        return _compressWithLowerQuality(file);
      }

      return compressedFile;
    } catch (e) {
      AppLogger.debug('❌ Compression error: $e');
      return file;
    }
  }

  /// Compress with lower quality if previous attempt was too large
  static Future<File> _compressWithLowerQuality(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final compressedPath = '${tempDir.path}/compressed_low_quality_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        compressedPath,
        quality: 50, // Lower quality: 50%
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        return file;
      }

      final compressedFile = File(result.path);
      final compressedSizeBytes = await compressedFile.length();

      AppLogger.debug('✅ Image re-compressed with lower quality: ${_formatBytes(compressedSizeBytes)}');
      return compressedFile;
    } catch (e) {
      AppLogger.debug('❌ Low quality compression error: $e');
      return file;
    }
  }

  /// Format bytes to human-readable size
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get readable size string
  static String getReadableSize(File file) {
    final sizeBytes = file.lengthSync();
    return _formatBytes(sizeBytes);
  }

  /// Validate and compress in one operation
  /// Returns: (success, processedFile, errorMessage)
  static Future<(bool, File?, String?)> validateAndCompress(File file) async {
    // First validate
    final (isValid, validationError) = await validateScreenshot(file);
    if (!isValid) {
      return (false, null, validationError);
    }

    // Then compress
    try {
      final compressedFile = await compressImage(file);
      
      // Final size check after compression
      final finalSizeBytes = await compressedFile.length();
      if (finalSizeBytes > maxFileSizeBytes) {
        return (
          false,
          null,
          'File still too large after compression (${_formatBytes(finalSizeBytes)}). Please try a different image.'
        );
      }

      return (true, compressedFile, null);
    } catch (e) {
      return (false, null, 'Compression failed: $e');
    }
  }
}


