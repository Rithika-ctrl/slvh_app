/// Legal document configuration
/// 
/// CRITICAL: These URLs are required for:
/// - Play Store compliance (Privacy Policy mandatory)
/// - GDPR/legal compliance
/// - User privacy rights
/// 
/// Setup Instructions:
/// 1. Create your privacy policy and terms of service documents
/// 2. Host them on Firebase Hosting or your domain
/// 3. Update the URLs below with actual links
/// 
/// Option A: Firebase Hosting (Recommended)
/// - Deploy HTML files: firebase deploy --only hosting
/// - URLs format: https://YOUR_PROJECT_ID.web.app/privacy-policy
/// 
/// Option B: External Hosting
/// - Any HTTPS URL that serves your legal documents
/// - Example: https://yourcompany.com/privacy-policy
class LegalConfig {
  LegalConfig._();

  /// Privacy Policy URL - REQUIRED for Play Store
  /// 
  /// ⚠️ CRITICAL: This must be a valid HTTPS URL pointing to your privacy policy
  /// Update this with your actual privacy policy URL before production deployment
  static const String privacyPolicyUrl = 'https://slvh-smart-shop.firebaseapp.com/privacy-policy';

  /// Terms of Service URL - Required by many payment processors
  /// 
  /// ⚠️ CRITICAL: This must be a valid HTTPS URL pointing to your terms
  /// Update this with your actual terms of service URL before production deployment
  static const String termsOfServiceUrl = 'https://slvh-smart-shop.firebaseapp.com/terms-of-service';

  /// Support email for legal inquiries
  static const String supportEmail = 'support@slvhsmartshop.com';

  /// Validates that legal URLs are configured (not placeholder values)
  static bool get isConfigured =>
      !privacyPolicyUrl.contains('YOUR_PROJECT_ID') &&
      !termsOfServiceUrl.contains('YOUR_PROJECT_ID') &&
      privacyPolicyUrl.startsWith('https://') &&
      termsOfServiceUrl.startsWith('https://');

  /// Returns configuration status for logging/debugging
  static String getConfigStatus() {
    if (!isConfigured) {
      return '❌ CRITICAL: Legal URLs not configured. Update LegalConfig before deployment.';
    }
    return '✅ Legal URLs configured:\n'
        '   Privacy: $privacyPolicyUrl\n'
        '   Terms: $termsOfServiceUrl';
  }
}
