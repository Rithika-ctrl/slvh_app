# Push Notifications (FCM) Implementation Guide

## Overview
This document describes the Firebase Cloud Messaging (FCM) push notification system for the SLVH Smart Shop app. The system notifies customers when their order status changes.

## Architecture

### Components

1. **NotificationModel** (`lib/features/notifications/models/notification_model.dart`)
   - Data structure for notifications
   - Fields: id, userId, title, body, orderId, orderStatus, isRead, createdAt, actionUrl
   - Serialization methods: `toFirestore()`, `fromFirestore()`
   - NotificationType enum for predefined messages

2. **NotificationService** (`lib/features/notifications/services/notification_service.dart`)
   - Singleton service managing FCM and local notifications
   - Core methods:
     - `initialize()` - Setup FCM, request permissions, register message handlers
     - `saveFCMTokenForUser(userId)` - Save FCM token to Firestore
     - `sendLocalNotification()` - Display local notification to user
     - `saveNotification()` - Store notification in Firestore history
     - `watchUserNotifications(userId)` - Real-time stream of user notifications
     - Message handlers for foreground/background/tap events

3. **NotificationsScreen** (`lib/features/notifications/screens/notifications_screen.dart`)
   - UI to display user's notification history
   - Real-time updates via StreamBuilder
   - Delete, mark as read functionality
   - Tap navigation to order details

4. **OrderService Integration** (`lib/features/orders/services/order_service.dart`)
   - `updateOrderStatus()` now sends notifications
   - `_sendOrderStatusNotification()` handles notification sending
   - Sends notifications for: confirmed, preparing, readyForPickup, completed, cancelled

## Flow Diagram

```
Customer logs in
    ↓
AuthService._saveLoginState() called
    ↓
NotificationService.saveFCMTokenForUser() saves token to users/{phoneNumber}
    ↓
Order is created
    ↓
Admin updates order status via AdminDashboard
    ↓
OrderService.updateOrderStatus() called
    ↓
_sendOrderStatusNotification() saves notification to Firestore
    ↓
Notification appears in NotificationsScreen (real-time via StreamBuilder)
    ↓
For foreground messages: Local notification appears in notification tray
    ↓
User taps notification → Navigate to OrderDetailScreen
```

## Firestore Schema

### Users Collection
```
users/{phoneNumber}
├── fcmToken: String          // Firebase Cloud Messaging token
├── notificationsEnabled: Boolean
└── updatedAt: DateTime
```

### Notifications Subcollection
```
users/{phoneNumber}/notifications/{notificationId}
├── id: String
├── userId: String
├── title: String
├── body: String
├── orderId: String
├── orderStatus: String
├── isRead: Boolean
├── createdAt: DateTime
└── actionUrl: String
```

## Integration Points

### 1. App Initialization (main.dart)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Notifications
  await NotificationService().initialize();
  
  runApp(const SLVHApp());
}
```

### 2. Authentication Flow (auth_service.dart)
```dart
Future<void> _saveLoginState(String phoneNumber) async {
  // ... existing code ...
  
  // Save FCM token for push notifications
  await NotificationService().saveFCMTokenForUser(phoneNumber);
}
```

### 3. Order Status Updates (order_service.dart)
```dart
Future<void> updateOrderStatus(
  String orderId,
  OrderStatus newStatus,
) async {
  // Update Firestore
  await _firestore.collection('orders').doc(orderId).update({
    'status': newStatus.name,
    'updatedAt': DateTime.now(),
  });
  
  // Send notification to customer
  _sendOrderStatusNotification(
    orderId: orderId,
    customerId: order.customerId,
    newStatus: newStatus,
  );
}
```

### 4. Routing (app_router.dart)
```dart
GoRoute(
  path: AppRoutes.notifications,
  name: 'notifications',
  builder: (context, state) {
    final phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    return NotificationsScreen(userId: phoneNumber);
  },
),
```

## Testing Guide

### Prerequisites
- Physical Android or iOS device (FCM doesn't work on emulators)
- Firebase project with Cloud Messaging enabled
- Google Play Services installed on Android device

### Step 1: Manual Testing (Foreground)

1. **Start the app:**
   - `flutter run`

2. **Login as customer:**
   - Phone: +91XXXXXXXXXX
   - OTP: 123456

3. **Verify FCM token saved:**
   - Go to Firebase Console
   - Firestore → users → {phoneNumber}
   - Verify `fcmToken` field exists

4. **Create an order:**
   - Go to home
   - Select products
   - Add to cart
   - Proceed to checkout
   - Select pickup slot
   - Make payment
   - Order created successfully

5. **Update order status (Admin):**
   - Login as admin (email: admin@smartshop.com, password: admin123)
   - Go to Orders Management
   - Select the order
   - Change status to "Confirmed"
   - Note the time

6. **Check notification (Customer):**
   - Keep customer app open (foreground)
   - Check notification tray
   - Should see: "✅ Order Confirmed"
   - Body: "Your payment has been verified. Your order is confirmed!"

7. **Verify notification history:**
   - Go to Notifications screen
   - Should see the notification
   - Status color should match order status

### Step 2: Background Testing

1. **Send order status update:**
   - Update order status from Admin dashboard
   - While customer app is in background (but not closed)
   
2. **App receives message:**
   - Message handler processes it
   - Local notification appears in notification tray
   - Android: Notification appears
   - iOS: Notification appears

3. **Tap notification:**
   - Notification taps trigger navigation
   - App opens and goes to OrderDetailScreen
   - Correct orderId is displayed

### Step 3: App Closed Testing

1. **Close customer app:**
   - Swipe away or force close

2. **Send order status update:**
   - Update order status from admin dashboard

3. **Receive notification (device level):**
   - Notification appears in device notification center
   - App is not running (cold start)

4. **Tap notification:**
   - App starts from scratch
   - Navigates to OrderDetailScreen
   - Displays correct order

### Step 4: Multiple Status Changes

Test the full order lifecycle:

1. Create order → Order created (no notification, payment pending)
2. Update to "Confirmed" → Notification sent
3. Update to "Preparing" → Notification sent
4. Update to "ReadyForPickup" → Notification sent
5. Update to "Completed" → Notification sent

### Step 5: Error Scenarios

1. **Network unavailable:**
   - Turn off WiFi and mobile data
   - Send notification
   - When network returns, notification should still be saved

2. **Permission denied:**
   - On iOS: User denies notification permission
   - Notification still saved to Firestore
   - Can view in NotificationsScreen

3. **Token refresh:**
   - App updates FCM token when it refreshes
   - New token is saved to Firestore

## Monitoring & Debugging

### Firebase Console

1. **View sent messages:**
   - Firebase Console → Cloud Messaging
   - Check message delivery status

2. **View FCM tokens:**
   - Firestore → users collection
   - Verify `fcmToken` fields are populated

3. **Monitor errors:**
   - Cloud Firestore → Rules (check security rules)
   - Verify users/{phoneNumber} documents can be written to

### Debug Logging

Enable debug logging for FCM:

```dart
// In NotificationService.initialize()
FirebaseMessaging.instance.setAutoInitEnabled(true);

// View logs in Flutter console
// Look for: "✅ Notification" prefix
```

## Cloud Functions (Backend Setup)

**Status:** Optional for Phase 3. Notifications currently handled client-side.

In production, you may want to:

1. **Deploy Cloud Function** to send FCM messages:
   ```javascript
   exports.orderStatusChanged = functions.firestore
     .document('orders/{orderId}')
     .onUpdate(async (change, context) => {
       const newStatus = change.after.data().status;
       const customerId = change.after.data().customerId;
       
       const userDoc = await admin.firestore()
         .collection('users')
         .doc(customerId)
         .get();
       
       const fcmToken = userDoc.data().fcmToken;
       
       if (fcmToken) {
         await admin.messaging().send({
           token: fcmToken,
           data: {
             orderId: context.params.orderId,
             status: newStatus,
           },
         });
       }
     });
   ```

2. **Benefits:**
   - Server-side control over notifications
   - Guaranteed delivery (retries handled by Firebase)
   - Batch operations possible
   - Real-time rules enforcement

## Troubleshooting

### Issue: Notifications not appearing

**Causes:**
1. FCM token not saved - Check Firestore users collection
2. App in background with DoNotDisturb enabled
3. Notification permissions denied
4. Device not connected to internet

**Solution:**
1. Verify `fcmToken` in Firestore
2. Check device notification settings
3. Grant notification permission in Settings
4. Verify network connectivity

### Issue: App crashes on notification tap

**Causes:**
1. `_navigateToOrderDetail()` not properly implemented
2. GoRouter context not available in background handler

**Solution:**
1. Implement named route or use GoRouter properly
2. Queue navigation events for app startup

### Issue: Token not refreshing

**Causes:**
1. `onTokenRefresh` listener not properly registered
2. App not receiving token refresh event

**Solution:**
1. Check NotificationService initialization
2. Restart app to trigger refresh

## Summary of Files Created/Modified

### Created:
- `lib/features/notifications/models/notification_model.dart` (130 lines)
- `lib/features/notifications/services/notification_service.dart` (400+ lines)
- `lib/features/notifications/screens/notifications_screen.dart` (280 lines)

### Modified:
- `slvh_app/pubspec.yaml` - Added firebase_messaging, flutter_local_notifications
- `lib/main.dart` - Initialize NotificationService
- `lib/features/auth/services/auth_service.dart` - Save FCM token on login
- `lib/features/orders/services/order_service.dart` - Send notifications on status change
- `lib/routes/app_router.dart` - Added notifications route and screen

### Dependencies Added:
- `firebase_messaging: ^15.0.0`
- `flutter_local_notifications: ^17.0.0`

## Next Steps

1. **Configure Firebase Console:**
   - Enable Cloud Messaging
   - Create service account for Cloud Functions (if deploying functions)

2. **Test on physical device:**
   - Android: Ensure Google Play Services updated
   - iOS: Ensure provisioning profile includes push notification capability

3. **Monitor analytics:**
   - Track notification delivery rates
   - Monitor user engagement with notifications

4. **Deploy Cloud Functions (Optional):**
   - For server-side control and guaranteed delivery

5. **Performance optimization:**
   - Batch notification saves
   - Implement notification grouping
   - Add notification expiry (old notifications auto-delete)
