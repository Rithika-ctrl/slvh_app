import 'dart:typed_data';

class ProductImageUpload {
  final String fileName;
  final Uint8List bytes;
  final String contentType;

  const ProductImageUpload({
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  int get sizeInKb => (bytes.length / 1024).ceil();
}