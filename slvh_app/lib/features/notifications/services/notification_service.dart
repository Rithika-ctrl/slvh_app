import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/notifications/models/notification_model.dart';

/// Top-level background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('✅ Handling background message in native code');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
}

/// Service for managing Firebase Cloud Messaging (FCM) and local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  bool _isInitialized = false;

  /// Initialize Firebase Cloud Messaging and Local Notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions (iOS)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.denied) {
        print('✅ Notification permissions granted');
      } else {
        print('⚠️ Notification permissions denied');
      }

      // Initialize local notifications
      _initializeLocalNotifications();

      // Get FCM token and save to Firestore
      await _saveFCMToken();

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle notification tap (app in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      _isInitialized = true;
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize NotificationService: $e');
    }
  }

  /// Initialize Flutter Local Notifications
  void _initializeLocalNotifications() {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Android initialization
    const androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  /// Save FCM token to Firestore user document
  Future<void> _saveFCMToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        print('FCM Token: $token');

        // Get current user UID from SharedPreferences or Auth
        // For now, we'll save to a temp location
        // In production, save after user logs in:
        // await _firestore.collection('users').doc(uid).update({
        //   'fcmToken': token,
        //   'updatedAt': DateTime.now(),
        // });

        // Store for later when user logs in
        await _firestore
            .collection('app_settings')
            .doc('fcm_tokens')
            .set({'temp_token': token}, SetOptions(merge: true));
      }
    } catch (e) {
      print('❌ Failed to save FCM token: $e');
    }
  }

  /// Save FCM token for authenticated user
  Future<void> saveFCMTokenForUser(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token,
          'updatedAt': DateTime.now(),
        }, SetOptions(merge: true));

        print('✅ FCM token saved for user: $userId');
      }
    } catch (e) {
      print('❌ Failed to save FCM token for user: $e');
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('✅ Foreground message received:');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    // Show local notification
    await _showLocalNotification(message);
  }

  /// Handle notification tap when app is in background
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('✅ Notification tapped (app in background)');
    _navigateToOrderDetail(message.data);
  }

  /// Handle local notification tap
  Future<void> _onLocalNotificationTap(
    NotificationResponse notificationResponse,
  ) async {
    print('✅ Local notification tapped');
    // Extract payload and navigate
    final payload = notificationResponse.payload;
    if (payload != null) {
      final parts = payload.split('|');
      if (parts.length >= 2) {
        _navigateToOrderDetail({
          'orderId': parts[0],
          'status': parts[1],
        });
      }
    }
  }

  /// Navigate to order detail screen
  void _navigateToOrderDetail(Map<String, dynamic> data) {
    final orderId = data['orderId'] as String?;
    if (orderId != null && orderId.isNotEmpty) {
      // This will be called from GoRouter context in real implementation
      print('📱 Navigate to order detail: $orderId');
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final android = AndroidNotificationDetails(
      'order_channel',
      'Order Notifications',
      channelDescription: 'Notifications for order status updates',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      color: const Color.fromARGB(255, 255, 152, 0), // Orange
    );

    final ios = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: android,
      iOS: ios,
    );

    final title = message.notification?.title ?? 'Smart Shop';
    final body = message.notification?.body ?? 'You have a new notification';
    final orderId = message.data['orderId'] as String? ?? '';
    final status = message.data['status'] as String? ?? '';

    // Payload for tap handling
    final payload = '$orderId|$status';

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Create and send local notification manually
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    required String orderId,
    String? status,
  }) async {
    try {
      final android = AndroidNotificationDetails(
        'order_channel',
        'Order Notifications',
        channelDescription: 'Notifications for order status updates',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        color: const Color.fromARGB(255, 255, 152, 0),
      );

      final ios = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: android,
        iOS: ios,
      );

      final payload = '$orderId|$status';

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecond,
        title,
        body,
        details,
        payload: payload,
      );

      print('✅ Local notification sent: $title');
    } catch (e) {
      print('❌ Failed to send local notification: $e');
    }
  }

  /// Save notification to Firestore for history
  Future<void> saveNotification({
    required String userId,
    required String title,
    required String body,
    required String orderId,
    String? orderStatus,
    String? actionUrl,
  }) async {
    try {
      final notificationRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc();

      final notification = NotificationModel(
        id: notificationRef.id,
        userId: userId,
        title: title,
        body: body,
        orderId: orderId,
        orderStatus: orderStatus,
        createdAt: DateTime.now(),
        actionUrl: actionUrl,
      );

      await notificationRef.set(notification.toFirestore());
      print('✅ Notification saved to Firestore: $title');
    } catch (e) {
      print('❌ Failed to save notification: $e');
    }
  }

  /// Get user notifications
  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('❌ Failed to fetch notifications: $e');
      return [];
    }
  }

  /// Stream of user notifications (real-time)
  Stream<List<NotificationModel>> watchUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      print('✅ Notification marked as read');
    } catch (e) {
      print('❌ Failed to mark notification as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      print('✅ Notification deleted');
    } catch (e) {
      print('❌ Failed to delete notification: $e');
    }
  }

  /// Enable notifications for user
  Future<void> enableNotifications(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationsEnabled': true,
        'updatedAt': DateTime.now(),
      });

      print('✅ Notifications enabled for user: $userId');
    } catch (e) {
      print('❌ Failed to enable notifications: $e');
    }
  }

  /// Disable notifications for user
  Future<void> disableNotifications(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationsEnabled': false,
        'updatedAt': DateTime.now(),
      });

      print('✅ Notifications disabled for user: $userId');
    } catch (e) {
      print('❌ Failed to disable notifications: $e');
    }
  }
}
