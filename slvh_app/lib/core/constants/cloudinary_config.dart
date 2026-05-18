class CloudinaryConfig {
  CloudinaryConfig._();

  static const String cloudName = 'dpi4ozchf';
  static const String apiKey = '878649597265367';

  /// CRITICAL SECURITY: API Secret must NOT be hardcoded in source code.
  /// 
  /// This secret was previously hardcoded and committed to git.
  /// IMMEDIATE ACTIONS REQUIRED:
  /// 1. Regenerate your Cloudinary API secret at https://cloudinary.com/console/settings/security
  /// 2. Store the new secret in:
  ///    - Android: res/values/secrets.xml or environment variable
  ///    - iOS: Info.plist or environment variable
  ///    - Backend: Environment variable or secure config service
  /// 3. Load the secret at runtime from secure storage, NOT from source code
  /// 4. NEVER commit real secrets to git
  /// 
  /// For development: Set via CloudinaryUploadService constructor parameter
  /// For production: Load from environment/secure config at app startup
  static const String apiSecret = '';

  static const String productFolder = 'slvh/products';
}