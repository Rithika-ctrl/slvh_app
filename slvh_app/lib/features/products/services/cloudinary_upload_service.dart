import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/cloudinary_config.dart';
import '../models/product_image_upload.dart';
import 'cloudinary_config_service.dart';

class CloudinaryUploadException implements Exception {
  final String message;

  const CloudinaryUploadException(this.message);

  @override
  String toString() => message;
}

class CloudinaryImageAsset {
  final String secureUrl;
  final String publicId;

  const CloudinaryImageAsset({
    required this.secureUrl,
    required this.publicId,
  });
}

class CloudinaryUploadService {
  CloudinaryUploadService({
    http.Client? client,
    String? cloudName,
    String? apiKey,
    String? apiSecret,
    String? folder,
  })  : _client = client ?? http.Client(),
        cloudName = cloudName ?? CloudinaryConfigService().cloudName,
        apiKey = apiKey ?? CloudinaryConfigService().apiKey,
        apiSecret = apiSecret ?? CloudinaryConfigService().apiSecret,
        folder = folder ?? CloudinaryConfigService().productFolder;

  final http.Client _client;
  final String cloudName;
  final String apiKey;
  final String apiSecret;
  final String folder;

  bool get _useSignedUploads => apiSecret.trim().isNotEmpty;

  Future<List<CloudinaryImageAsset>> uploadProductImages({
    required String productId,
    required List<ProductImageUpload> images,
  }) async {
    final uploads = <CloudinaryImageAsset>[];

    for (final image in images) {
      uploads.add(
        await uploadSingleImage(
          productId: productId,
          image: image,
        ),
      );
    }

    return uploads;
  }

  Future<CloudinaryImageAsset> uploadSingleImage({
    required String productId,
    required ProductImageUpload image,
  }) async {
    if (!_useSignedUploads) {
      throw CloudinaryUploadException(
        'Cloudinary apiSecret is empty. Set it in cloudinary_config.dart before uploading.',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final normalizedFileName = _normalizeFileName(image.fileName);
    final baseName = normalizedFileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final publicId = '$folder/$productId/$baseName';

    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp.toString()
      ..fields['public_id'] = publicId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          image.bytes,
          filename: normalizedFileName,
        ),
      );

    request.fields['signature'] = _buildSignature({
      'public_id': publicId,
      'timestamp': timestamp.toString(),
    });

    final response = await _client.send(request);
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudinaryUploadException(_parseError(body));
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final secureUrl = decoded['secure_url'] as String?;
    final returnedPublicId = decoded['public_id'] as String? ?? publicId;

    if (secureUrl == null || secureUrl.isEmpty) {
      throw const CloudinaryUploadException(
        'Cloudinary did not return a secure URL.',
      );
    }

    return CloudinaryImageAsset(
      secureUrl: secureUrl,
      publicId: returnedPublicId,
    );
  }

  Future<void> deleteImagesByUrls(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImageByUrl(url);
    }
  }

  Future<void> deleteImageByUrl(String imageUrl) async {
    if (!_useSignedUploads) {
      throw CloudinaryUploadException(
        'Cloudinary apiSecret is empty. Set it in cloudinary_config.dart before deleting images.',
      );
    }

    final publicId = _extractPublicIdFromUrl(imageUrl);
    if (publicId.isEmpty) {
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$cloudName/image/destroy',
    );

    final response = await _client.post(
      uri,
      body: {
        'api_key': apiKey,
        'timestamp': timestamp.toString(),
        'public_id': publicId,
        'signature': _buildSignature({
          'public_id': publicId,
          'timestamp': timestamp.toString(),
        }),
      },
    );
    final body = response.body;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudinaryUploadException(_parseError(body));
    }
  }

  String _buildSignature(Map<String, String> params) {
    final sortedKeys = params.keys.toList()..sort();
    final serialized = sortedKeys.map((key) => '$key=${params[key]}').join('&');
    final signaturePayload = '$serialized$apiSecret';
    return sha1.convert(utf8.encode(signaturePayload)).toString();
  }

  String _extractPublicIdFromUrl(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      final uploadIndex = segments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 2 >= segments.length) {
        return '';
      }

      final publicIdSegments = segments.sublist(uploadIndex + 2);
      if (publicIdSegments.isEmpty) {
        return '';
      }

      final publicIdWithExtension = publicIdSegments.join('/');
      return Uri.decodeComponent(
        publicIdWithExtension.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      );
    } catch (_) {
      return '';
    }
  }

  String _normalizeFileName(String fileName) {
    final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return sanitized.endsWith('.jpg') || sanitized.endsWith('.jpeg')
        ? sanitized
        : '$sanitized.jpg';
  }

  String _parseError(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        return error['message'] as String? ?? body;
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}