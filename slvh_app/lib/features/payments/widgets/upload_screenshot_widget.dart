import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Widget for uploading payment screenshot
class ScreenshotUploadWidget extends StatefulWidget {
  final VoidCallback onUploadStart;
  final Function(File) onImageSelected;
  final Function(String) onUploadSuccess;
  final Function(String) onUploadError;
  final bool isUploading;
  final String? uploadedImagePath;

  const ScreenshotUploadWidget({
    Key? key,
    required this.onUploadStart,
    required this.onImageSelected,
    required this.onUploadSuccess,
    required this.onUploadError,
    this.isUploading = false,
    this.uploadedImagePath,
  }) : super(key: key);

  @override
  State<ScreenshotUploadWidget> createState() =>
      _ScreenshotUploadWidgetState();
}

class _ScreenshotUploadWidgetState extends State<ScreenshotUploadWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    if (widget.uploadedImagePath != null) {
      _selectedImage = File(widget.uploadedImagePath!);
    }
  }

  /// Pick image from gallery
  Future<void> _pickFromGallery() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() {
          _selectedImage = file;
        });
        widget.onImageSelected(file);
      }
    } catch (e) {
      widget.onUploadError('Failed to pick image: $e');
    }
  }

  /// Take photo with camera
  Future<void> _pickFromCamera() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() {
          _selectedImage = file;
        });
        widget.onImageSelected(file);
      }
    } catch (e) {
      widget.onUploadError('Failed to capture image: $e');
    }
  }

  /// Show image source selection bottom sheet
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select Screenshot Source',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Upload Payment Proof',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          // Image preview or upload area
          if (_selectedImage == null)
            _buildUploadArea()
          else
            _buildImagePreview(),

          const SizedBox(height: 12),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Upload a screenshot of your payment confirmation',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '✓ Shows UPI transaction ID\n✓ Shows amount and timestamp\n✓ Shows "Success" status',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build upload area (when no image selected)
  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: widget.isUploading ? null : _showImageSourceDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.orange[300]!,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Colors.orange[50],
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 48,
              color: Colors.orange[700],
            ),
            const SizedBox(height: 12),
            Text(
              'Tap to Upload Screenshot',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'or',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Take a photo with camera',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build image preview (when image is selected)
  Widget _buildImagePreview() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedImage!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.isUploading ? null : _showImageSourceDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Change'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.isUploading ? null : () {
                  widget.onUploadStart();
                },
                icon: widget.isUploading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(widget.isUploading ? 'Uploading...' : 'Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),

        // Success message
        if (widget.uploadedImagePath != null && !widget.isUploading) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green[700],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Screenshot uploaded successfully',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
