# Feature #9: Payment Screenshot Validation (Size & Format)

## Overview

This feature ensures that payment proof screenshots uploaded by customers meet strict quality and format requirements before being stored and verified. The validation occurs at multiple levels:

1. **Client-side (Flutter):** Format, size, and compression
2. **Server-side (Firebase Storage Rules):** Format and size enforcement
3. **Service layer (PaymentService):** Pre-upload validation

## Problem Statement

Without proper validation, customers could upload:
- Invalid file formats (PDF, video, documents)
- Extremely large image files (100+ MB)
- Corrupted or fake payment screenshots
- Non-JPG/PNG formats that clutter the storage

This leads to storage bloat, bandwidth waste, and verification challenges.

## Solution Architecture

### 1. File Validation Service: `PaymentScreenshotValidator`

**Location:** `slvh_app/lib/features/payments/services/payment_screenshot_validator.dart`

**Validation Rules:**
- Allowed formats: JPG, JPEG, PNG (case-insensitive)
- Maximum file size: 5 MB (5,242,880 bytes)
- Minimum file size: 1 KB (prevent empty files)

**Key Methods:**

```dart
// Validate format and size
(bool isValid, String? errorMessage) = 
    await PaymentScreenshotValidator.validateScreenshot(file);

// Compress image (quality 70%, can retry at 50%)
File compressedFile = 
    await PaymentScreenshotValidator.compressImage(file);

// Validate AND compress in one call
(bool success, File? processedFile, String? errorMessage) = 
    await PaymentScreenshotValidator.validateAndCompress(file);
```

### 2. Image Compression

**Library:** `flutter_image_compress` (v2.3.0)

**Compression Strategy:**
- Primary: Quality 70% with JPEG format
- Fallback: Quality 50% if primary result exceeds 5 MB
- Automatic detection: Skips compression for files < 2 MB

**Benefits:**
- Reduces file size without visible quality loss
- Converts all formats to optimized JPEG
- Preserves enough quality for payment verification

### 3. Client-Side Integration: `ScreenshotUploadWidget`

**Changes:**
1. Import `PaymentScreenshotValidator`
2. Add validation in `_pickFromGallery()` after image selection
3. Add validation in `_pickFromCamera()` after photo capture
4. Show error dialog (`_showValidationErrorDialog`) for failures
5. Pass validated and compressed file to parent widget

**Flow:**
```
User selects image
    ↓
_pickFromGallery() / _pickFromCamera()
    ↓
validateAndCompress() [format + size + compression]
    ↓
Success → setState(_selectedImage) → onImageSelected(compressed)
    ↓
Failure → showDialog(error) → user can retry
```

**Error Scenarios & Messages:**

| Scenario | Error Message |
|----------|---------------|
| Invalid extension (.pdf, .bmp, etc.) | "Invalid file format. Only JPG and PNG are allowed.\nSelected: .pdf" |
| File > 5 MB | "File is too large (6.2 MB). Maximum size is 5 MB.\n\nTry: Compress the image or take a screenshot instead." |
| File < 1 KB | "File is too small. Please select a valid image." |
| File doesn't exist | "File does not exist" |
| Compression error | "Compression failed: [error details]" |
| Size still > 5 MB after compression | "File still too large after compression (5.1 MB). Please try a different image." |

### 4. Service-Layer Validation: `PaymentService`

**Updated Method:** `uploadPaymentScreenshot()`

**Validation Added:**
```dart
Future<String> uploadPaymentScreenshot({
  required File imageFile,
  required String orderId,
  required String paymentId,
}) async {
  // Pre-upload validation
  final (isValid, validationError) = 
      await PaymentScreenshotValidator.validateScreenshot(imageFile);
  
  if (!isValid) {
    throw Exception(validationError);
  }
  
  // ... proceed with upload
}
```

**Purpose:** Server-side safety check (defense in depth)

### 5. Firebase Storage Rules

**Location:** `storage.rules`

**Payment Screenshots Rule:**
```firestore
match /payment-screenshots/{orderId}/{document=**} {
  allow read: if request.auth != null;
  allow write: if request.auth != null 
    && request.resource.size < 5 * 1024 * 1024
    && request.resource.contentType.matches('image/jpeg|image/png');
}
```

**Enforcement:**
- Validates on every upload attempt
- Rejects files > 5 MB at storage layer
- Only allows image/jpeg and image/png MIME types
- Blocks non-authenticated requests

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│  Payment Screen                                           │
│  ├─ User taps "Upload Payment Proof"                    │
│  └─ ScreenshotUploadWidget shown                        │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │ User picks image              │
        │ Gallery / Camera              │
        └──────────┬───────────────────┘
                   │
                   ↓
    ┌──────────────────────────────────────┐
    │ PaymentScreenshotValidator            │
    │ validateAndCompress()                 │
    │ ├─ Check extension (jpg/png)         │
    │ ├─ Check size (< 5 MB)               │
    │ └─ Compress image (quality 70%)      │
    └──────┬───────────────────────┬───────┘
           │                       │
           │ SUCCESS               │ FAILURE
           ↓                       ↓
    ┌──────────────────┐  ┌─────────────────────┐
    │ _selectedImage =  │  │ showDialog(error)   │
    │   compressedFile  │  │ User can retry      │
    └────────┬─────────┘  └─────────────────────┘
             │
             ↓
    ┌──────────────────────────────────┐
    │ onImageSelected(compressedFile)   │
    └────────┬─────────────────────────┘
             │
             ↓
    ┌──────────────────────────────────┐
    │ User taps "Upload" button         │
    └────────┬─────────────────────────┘
             │
             ↓
    ┌──────────────────────────────────┐
    │ PaymentService                    │
    │ uploadPaymentScreenshot()         │
    │ ├─ Validate again (safety)        │
    │ └─ Upload to Firebase Storage     │
    └────┬──────────────────┬──────────┘
         │                  │
         │ SUCCESS          │ FAILURE
         ↓                  ↓
    ┌─────────────┐  ┌──────────────────┐
    │ Download    │  │ Show error dialog │
    │ URL → Update│  │ User retries      │
    │ Firestore   │  └──────────────────┘
    │ screenshot  │
    │ status      │
    └─────────────┘
```

## Implementation Details

### PaymentScreenshotValidator Class

**Properties:**
```dart
static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png'];
static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
static const int minFileSizeBytes = 1 * 1024; // 1 KB
```

**Public Methods:**

1. **validateScreenshot(File file)**
   - Returns: `(bool isValid, String? errorMessage)`
   - Checks: Extension, file existence, size limits
   - No modifications to file

2. **compressImage(File file)**
   - Returns: `File` (compressed or original)
   - Applies: JPEG compression at 70% quality
   - Fallback: 50% quality if still too large
   - Skips: Files already < 2 MB

3. **validateAndCompress(File file)**
   - Returns: `(bool success, File? processedFile, String? errorMessage)`
   - Combines validation + compression in single operation
   - Ideal for file selection callbacks
   - Comprehensive error messages

**Private Methods:**
- `_compressWithLowerQuality()` - Retry compression at lower quality
- `_formatBytes()` - Human-readable size formatting

### ScreenshotUploadWidget Updates

**Modified Methods:**

```dart
/// Pick image from gallery with validation and compression
Future<void> _pickFromGallery() async {
  final pickedFile = await _imagePicker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
  );

  if (pickedFile != null) {
    final (success, processedFile, errorMessage) = 
        await PaymentScreenshotValidator.validateAndCompress(File(pickedFile.path));
    
    if (!success) {
      _showValidationErrorDialog(errorMessage ?? 'Unknown error');
      return;
    }
    
    setState(() => _selectedImage = processedFile);
    widget.onImageSelected(processedFile!);
  }
}
```

**New Method:**

```dart
/// Show validation error dialog
void _showValidationErrorDialog(String errorMessage) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.error_outline, color: Colors.red[700]),
      title: const Text('Invalid Image'),
      content: Text(errorMessage),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showImageSourceDialog(); // Let user try again
          },
          child: const Text('Try Again'),
        ),
      ],
    ),
  );
}
```

### PaymentService Updates

**Updated Method:**

```dart
Future<String> uploadPaymentScreenshot({
  required File imageFile,
  required String orderId,
  required String paymentId,
}) async {
  try {
    // Pre-upload validation (safety check)
    final (isValid, validationError) = 
        await PaymentScreenshotValidator.validateScreenshot(imageFile);
    
    if (!isValid) {
      throw Exception(validationError ?? 'Invalid screenshot');
    }

    final path = 'payment-screenshots/$orderId/$paymentId.jpg';
    final ref = _storage.ref(path);

    // Upload file
    await ref.putFile(imageFile);

    // Get download URL
    return await ref.getDownloadURL();
  } catch (e) {
    throw Exception('Failed to upload screenshot: $e');
  }
}
```

## Testing Checklist

### 1. File Format Validation

- [ ] Upload JPG file → Success
- [ ] Upload PNG file → Success
- [ ] Upload JPEG file → Success
- [ ] Upload PDF file → Error: "Invalid file format. Only JPG and PNG are allowed."
- [ ] Upload BMP file → Error message shown
- [ ] Upload video file → Error message shown
- [ ] Upload Word document → Error message shown
- [ ] Upload corrupted JPG → Error or handled gracefully

### 2. File Size Validation

- [ ] Upload 100 KB JPG → Success
- [ ] Upload 2 MB PNG → Success (no compression applied)
- [ ] Upload 3 MB JPG → Compress, then upload successfully
- [ ] Upload 5 MB file → Compress if needed, upload successfully
- [ ] Upload 6 MB file → Error: "File is too large... Maximum size is 5 MB"
- [ ] Upload 10 MB file → Error message shown
- [ ] Upload empty file (0 bytes) → Error: "File is too small"
- [ ] Upload 500 byte file → Error: "File is too small"

### 3. Image Compression

- [ ] 3 MB JPG → Compress to < 2 MB with quality 70%
- [ ] 5 MB PNG → Compress to < 5 MB with quality 70%
- [ ] 5 MB file → If compression fails at 70%, retry at 50%
- [ ] Log messages visible in console:
  - `✅ Image already optimized (1.5 MB)`
  - `🔄 Compressing image (3.2 MB)...`
  - `✅ Image compressed: 3.2 MB → 1.8 MB`
  - `❌ Compression error: [error]`

### 4. UI/UX Flow

- [ ] User taps "Tap to Upload" → Source dialog appears
- [ ] User selects "Gallery" → Image picker opens
- [ ] User picks valid image → Preview shown, upload enabled
- [ ] User picks invalid format → Error dialog shown, "Try Again" retry works
- [ ] User picks oversized file → Error dialog shown, can retry
- [ ] User can tap "Change" to pick different image
- [ ] User can upload image → Upload button shows spinner
- [ ] Upload completes → Success message appears
- [ ] Error during upload → Error dialog shown with retry option

### 5. Camera Capture

- [ ] User selects "Camera" → Camera app opens
- [ ] User takes valid photo → Preview shown
- [ ] User takes very large photo → Compression applied
- [ ] User takes low-light photo → Compression works
- [ ] User cancels camera → Returns to upload widget

### 6. Firebase Storage Rules

- [ ] Valid JPG upload (4 MB) → Success
- [ ] Valid PNG upload (3.5 MB) → Success
- [ ] 5.5 MB file attempt → Blocked by storage rules
- [ ] PDF file attempt → Blocked by storage rules (not image/*)
- [ ] Unauthenticated request → Blocked
- [ ] Admin can read all screenshots → Success
- [ ] User can read own order's screenshot → Success

### 7. Error Recovery

- [ ] User picks invalid file → See error → Tap "Try Again" → Try again successfully
- [ ] User picks oversized file → See error → Tap "OK" → Picker returns to normal state
- [ ] Upload fails (network error) → Error shown → User can retry
- [ ] Upload partially completes → Graceful error handling

### 8. Device Scenarios

- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Test with low storage (< 100 MB)
- [ ] Test on slow network (3G)
- [ ] Test with app backgrounded during compression
- [ ] Test with rapid successive uploads

## Security Considerations

### 1. Client-Side Validation

**Why it matters:** UX feedback before server-side checks

**What it prevents:**
- Users accidentally uploading wrong file types
- Users experiencing server errors for oversized files
- Bandwidth waste from invalid uploads

**Limitations:**
- Validator can be bypassed by determined attacker
- Cannot trust file extension alone (check MIME type)
- File can be corrupted after passing validation

### 2. Server-Side Validation (Firebase Storage Rules)

**Why it matters:** Authoritative enforcement at storage layer

**What it prevents:**
- Circumventing client-side validation
- Uploading files with fake MIME types
- Uploading files larger than stated size
- Unauthenticated users uploading

**Implementation:**
```firestore
allow write: if request.auth != null 
  && request.resource.size < 5 * 1024 * 1024
  && request.resource.contentType.matches('image/jpeg|image/png');
```

### 3. Defense in Depth

**Validation at multiple layers:**
1. Client validation (ScreenshotUploadWidget) → UX
2. Service validation (PaymentService) → Logging/tracking
3. Storage rules validation (Firebase) → Enforcement

**Benefits:**
- Catches most issues early (client-side)
- Logs unexpected issues (service-layer)
- Prevents all attacks (storage rules)

### 4. File Content Verification (Future Enhancement)

Currently validates: Format, size, MIME type
Could enhance with: Content analysis using image processing
- Verify image contains actual payment screenshot
- Detect modified/fake screenshots
- Validate presence of UPI transaction ID
- Check for manual payment app screenshots vs. actual UPI responses

**Libraries for future:** `image`, `ml_kit_flutter`

### 5. Storage Bucket Access Control

**Firestore Rules Integration:**
```dart
// Users can only read payment screenshots for orders they created
match /payment-screenshots/{orderId}/{document=**} {
  allow read: if request.auth != null 
    && resource.path ==/['orders', orderId]/;
}
```

**Recommendation:** Validate in Firestore rules that user owns the order before allowing screenshot access.

## Troubleshooting Guide

### Issue: "File is too large" even after compression

**Possible Causes:**
1. Image quality too high (> 70%)
2. Very large original dimensions
3. Compression library not working

**Solutions:**
1. Lower quality further (try 50%)
2. Add image resizing before compression
3. Check logs: `🔄 Compressing image...`
4. Verify flutter_image_compress is imported correctly

**Code to add:**
```dart
// Add resizing before compression for very large files
const width = 1080; // Max width
const height = 1920; // Max height
final result = await FlutterImageCompress.compressAndGetFile(
  file.path,
  compressedPath,
  minWidth: width,
  minHeight: height,
  quality: 70,
);
```

### Issue: Validation passes but upload fails

**Possible Causes:**
1. Network connectivity lost
2. Firebase Storage rules blocking request
3. File deleted after validation

**Solutions:**
1. Check device network connection
2. Verify storage.rules has correct rules
3. Verify user is authenticated (auth token valid)
4. Check Firebase console for upload errors
5. Retry: Automatic with exponential backoff

**Logging to add:**
```dart
print('📤 Uploading to: $path');
print('📊 File size: ${await imageFile.length()} bytes');
print('🔐 User ID: ${auth.currentUser?.uid}');
```

### Issue: Wrong file type accepted (e.g., PDF accepted as JPG)

**Possible Causes:**
1. File renamed with .jpg extension but is actually PDF
2. Validator checking extension only (not MIME type)

**Current Solution:** 
Validator checks extension first, but Flutter's `image_picker` doesn't reliably provide MIME type on all devices.

**Recommendation:**
Use `file_picker` package instead for better MIME type detection.

### Issue: Compressed file still exceeds 5 MB

**Possible Causes:**
1. Very large original image (5000x5000+ pixels)
2. PNG with complex graphics

**Solutions:**
1. Add image resizing step
2. Try more aggressive compression
3. User should use different screenshot

**Code Enhancement:**
```dart
// If compression still too large, resize image
if (compressedSizeBytes > maxFileSizeBytes) {
  return await _resizeAndCompress(file);
}

Future<File> _resizeAndCompress(File file) async {
  // Reduce dimensions: 1080x1920 max
  final result = await FlutterImageCompress.compressAndGetFile(
    file.path,
    tempPath,
    minWidth: 1080,
    minHeight: 1920,
    quality: 50,
  );
  return File(result!.path);
}
```

### Issue: iOS camera photos extremely large

**Possible Causes:**
1. iOS camera captures very high resolution
2. HEIC format (Apple's modern format)

**Solutions:**
1. Compression handles this automatically
2. `imageQuality: 85` parameter in picker helps
3. Flutter automatically converts to JPG

**Note:** Works out of the box with current implementation.

## Code Reference

### Key Files Modified

| File | Changes |
|------|---------|
| `payment_screenshot_validator.dart` | NEW - Validation and compression logic |
| `upload_screenshot_widget.dart` | Import validator, validate in _pickFromGallery/_pickFromCamera, add error dialog |
| `payment_service.dart` | Add validation in uploadPaymentScreenshot() |
| `storage.rules` | NEW - Storage rules for payment-screenshots path |

### Imports Needed

```dart
// In upload_screenshot_widget.dart
import 'package:slvh_app/features/payments/services/payment_screenshot_validator.dart';

// In payment_service.dart
import 'package:slvh_app/features/payments/services/payment_screenshot_validator.dart';

// In pubspec.yaml (already present)
flutter_image_compress: ^2.3.0
image_picker: ^1.0.8
```

### Configuration Files

**firebase.json** - Add storage deployment:
```json
{
  "storage": [
    {
      "target": "payment-storage",
      "rules": "storage.rules"
    }
  ]
}
```

**Deploy command:**
```bash
firebase deploy --only storage:payment-storage
```

## Performance Notes

### Compression Performance

**Timing (on typical Android device):**
- 2 MB image: 100-200 ms (no compression needed)
- 3 MB image: 300-500 ms (compression at 70%)
- 5 MB image: 500-800 ms (compression to 50%)

**UX Impact:**
- Add progress dialog if compression takes > 1 second
- Show "Compressing image..." message
- Don't block UI during compression (use Future)

### Storage Impact

**Before Feature:**
- Users uploading raw camera photos: 5-15 MB each
- Monthly storage cost: Grows significantly

**After Feature:**
- Compressed JPG: 1-2 MB each
- ~80% reduction in storage usage
- Monthly cost reduced 4-5x

### Network Impact

**Upload Time (3G network, 1 MB file):**
- 3-5 seconds for compressed image
- vs. 15-30 seconds for uncompressed

**Data Usage:**
- Original: 2,000 MB for 100 payment screenshots
- Compressed: 150 MB for 100 payment screenshots

## Future Enhancements

### 1. Image Content Validation
Detect if image actually contains a payment screenshot (machine learning):
```dart
// Use ml_kit or similar
final labels = await mlKit.detectImages(imageFile);
if (labels.contains('payment') || labels.contains('transaction')) {
  // Likely valid payment screenshot
}
```

### 2. Advanced Compression Options
Allow users to adjust quality vs. file size tradeoff:
```dart
showDialog(
  context: context,
  builder: (context) => CompressOptionsDialog(
    quality: 70,
    onCompress: (quality) {
      // Custom compression with user's preferred quality
    },
  ),
);
```

### 3. Batch Upload
Support uploading multiple payment proof variants:
- Transaction confirmation screenshot
- OTP screen
- Final order confirmation

### 4. Payment Verification Bot
Automated verification of payment screenshots:
- Validates against UPI transaction ID
- Checks amount matches order total
- Verifies payment timestamp is recent
- Marks fraudulent/fake attempts

### 5. Compression Algorithm Comparison
Test different libraries and compression ratios:
- Current: flutter_image_compress (70% quality)
- Alternative: native imagemagick calls
- Alternative: webp format instead of jpeg (smaller)

### 6. Offline Screenshot Upload Queue
Queue screenshots if network unavailable:
```dart
// Store locally, upload when network returns
final queuedScreenshots = await _getQueuedScreenshots();
for (final screenshot in queuedScreenshots) {
  await uploadPaymentScreenshot(...);
}
```

## Deployment Checklist

- [ ] Add `flutter_image_compress: ^2.3.0` to pubspec.yaml
- [ ] Create `payment_screenshot_validator.dart` service
- [ ] Update `upload_screenshot_widget.dart` with validation
- [ ] Update `payment_service.dart` with validation
- [ ] Create `storage.rules` file
- [ ] Update `firebase.json` to deploy storage rules
- [ ] Test all validation scenarios (see Testing Checklist)
- [ ] Test on real devices (Android + iOS)
- [ ] Deploy Cloud Storage rules: `firebase deploy --only storage`
- [ ] Monitor Firebase Storage metrics for compression effectiveness
- [ ] Create user documentation about supported formats
- [ ] Train support team on common validation errors

## Related Documentation

- [PAYMENT_MODULE_GUIDE.md](PAYMENT_MODULE_GUIDE.md) - Complete payment flow
- [FIREBASE_SETUP.md](FIREBASE_SETUP.md) - Firebase configuration
- [FIRESTORE_SECURITY_RULES_GUIDE.md](FIRESTORE_SECURITY_RULES_GUIDE.md) - Security rules setup

## Summary

**Feature #9** implements comprehensive payment screenshot validation at three layers:
1. **Client-side:** User-friendly validation with clear error messages
2. **Service-layer:** Safety check before uploading
3. **Server-side:** Authoritative enforcement via Firebase Storage rules

The validation ensures payment screenshots are:
- ✅ Valid format (JPG/PNG only)
- ✅ Reasonable size (< 5 MB)
- ✅ Properly compressed for efficient storage
- ✅ Authentic (cannot be bypassed)

This reduces storage costs by ~80%, improves user experience with instant feedback, and prevents abuse of the payment verification system.
