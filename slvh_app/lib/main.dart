import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'features/notifications/services/notification_service.dart';
import 'connectivity/connectivity_service.dart';      // ← Feature 11
import 'connectivity/pending_write_queue.dart';        // ← Feature 11
import 'features/cart/services/cart_service.dart';    // ← Feature 11
import 'features/products/services/cloudinary_config_service.dart';
import 'features/auth/services/auth_service.dart';    // ← H-3 Security Fix
import 'core/constants/legal_config.dart';
import 'core/utils/secure_logger.dart';
import 'core/services/app_check_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check (H-2 Security Fix)
  // Must be called AFTER Firebase.initializeApp() and BEFORE Firestore operations
  await AppCheckService.initialize();

  // Initialize admin accounts in Firestore (H-3 Security Fix)
  // Allows runtime admin revocation without code changes
  await AuthService.initializeAdminAccounts();

  // Initialize Cloudinary configuration from Firebase Remote Config
  await CloudinaryConfigService().initialize();

  // Validate legal configuration (Privacy Policy & Terms required for Play Store)
  if (!LegalConfig.isConfigured) {
    AppLogger.debug('⚠️ CRITICAL: ${LegalConfig.getConfigStatus()}');
    AppLogger.debug('   Update lib/core/constants/legal_config.dart before production deployment');
  }

  // Initialize Notifications
  await NotificationService().initialize();

  // ── Feature 11: Offline / No Internet Handling ──────────────────────────

  // 1. Init Hive (local persistent storage for the write queue)
  await Hive.initFlutter();

  // 2. Start monitoring connectivity — must come before PendingWriteQueue
  await ConnectivityService.instance.initialize();

  // 3. Open the Hive box and register the Firestore executor.
  //    cartQueueExecutor handles cart writes; add more executors here
  //    if you queue other write types (e.g. profile updates).
  await PendingWriteQueue.instance.initialize(
    executor: cartQueueExecutor,
  );

  // ── End Feature 11 ───────────────────────────────────────────────────────

  runApp(const SLVHApp());
}

