import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:slvh_app/core/constants/cloudinary_config.dart';

/// Service to initialize and manage Cloudinary configuration from Firebase Remote Config
/// 
/// Why Firebase Remote Config for secrets?
/// - Secrets are stored securely in Firebase (encrypted at rest, encrypted in transit)
/// - Can be updated without rebuilding the app
/// - Can have different values for different user segments, countries, or build flavors
/// - No secrets committed to git repository
/// - Access controlled via Firebase console permissions
/// 
/// Setup Steps:
/// 1. Go to Firebase Console → Remote Config
/// 2. Click "Add parameter"
/// 3. Create parameters:
///    - Key: cloudinary_secret
///      Value: YOUR_NEW_CLOUDINARY_SECRET_FROM_CLOUDINARY_CONSOLE
///    - Key: cloudinary_cloud_name
///      Value: dpi4ozchf
///    - Key: cloudinary_api_key
///      Value: 878649597265367
/// 4. Click "Publish changes"
class CloudinaryConfigService {
  static final CloudinaryConfigService _instance =
      CloudinaryConfigService._internal();

  factory CloudinaryConfigService() {
    return _instance;
  }

  CloudinaryConfigService._internal();

  late String _cloudName;
  late String _apiKey;
  late String _apiSecret;
  late String _productFolder;

  String get cloudName => _cloudName;
  String get apiKey => _apiKey;
  String get apiSecret => _apiSecret;
  String get productFolder => _productFolder;

  /// Initialize Cloudinary configuration from Firebase Remote Config
  /// 
  /// This method:
  /// 1. Sets up Remote Config with timeout settings
  /// 2. Sets default values (for offline fallback)
  /// 3. Fetches the latest values from Firebase
  /// 4. Stores them locally for use throughout the app
  /// 
  /// Call this in main.dart during app initialization:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await Firebase.initializeApp(...);
  ///   await CloudinaryConfigService().initialize();
  ///   runApp(const MyApp());
  /// }
  /// ```
  Future<void> initialize() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Configure timeout and minimum fetch interval
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Set default values (used if Firebase fetch fails or offline)
      // These defaults are safe to expose since apiSecret is empty
      await remoteConfig.setDefaults({
        'cloudinary_secret': '',
        'cloudinary_cloud_name': CloudinaryConfig.cloudName,
        'cloudinary_api_key': CloudinaryConfig.apiKey,
        'cloudinary_product_folder': CloudinaryConfig.productFolder,
      });

      // Fetch latest values from Firebase
      await remoteConfig.fetchAndActivate();

      // Load into local variables
      _cloudName = remoteConfig.getString('cloudinary_cloud_name');
      _apiKey = remoteConfig.getString('cloudinary_api_key');
      _apiSecret = remoteConfig.getString('cloudinary_secret');
      _productFolder = remoteConfig.getString('cloudinary_product_folder');

      print(
        '✅ Cloudinary config initialized from Firebase Remote Config\n'
        'Cloud Name: $_cloudName\n'
        'API Key: $_apiKey\n'
        'Product Folder: $_productFolder\n'
        'Secret configured: ${_apiSecret.isNotEmpty}',
      );
    } catch (e) {
      // If initialization fails, fall back to local constants
      print('⚠️ Failed to fetch Cloudinary config from Firebase: $e');
      print('Using local defaults from CloudinaryConfig');

      _cloudName = CloudinaryConfig.cloudName;
      _apiKey = CloudinaryConfig.apiKey;
      _apiSecret = CloudinaryConfig.apiSecret;
      _productFolder = CloudinaryConfig.productFolder;
    }
  }
}
