# Phase 3 Testing Checklist: Push Notifications (FCM)

## Checklist Format
- [ ] = Not started
- [x] = Completed
- [~] = In progress
- [!] = Issue found

---

## 1. Development Setup

### 1.1 Dependencies Installation
- [ ] Firebase Messaging added to pubspec.yaml
- [ ] Flutter Local Notifications added to pubspec.yaml
- [ ] Ran `flutter pub get`
- [ ] No dependency conflicts

### 1.2 File Creation
- [ ] NotificationModel created at lib/features/notifications/models/notification_model.dart
- [ ] NotificationService created at lib/features/notifications/services/notification_service.dart
- [ ] NotificationsScreen created at lib/features/notifications/screens/notifications_screen.dart
- [ ] All files compile without errors

### 1.3 Integration
- [ ] NotificationService imported in main.dart
- [ ] NotificationService.initialize() called in main()
- [ ] NotificationService imported in auth_service.dart
- [ ] FCM token saving integrated into _saveLoginState()
- [ ] NotificationService imported in order_service.dart
- [ ] Notification sending integrated into updateOrderStatus()
- [ ] NotificationsScreen route added to app_router.dart
- [ ] No compilation errors after integration

---

## 2. Firebase Console Setup

### 2.1 Cloud Messaging Configuration
- [ ] Firebase project selected in Google Cloud Console
- [ ] Cloud Messaging API enabled
- [ ] Service account created (if needed)
- [ ] google-services.json updated in Android
- [ ] GoogleService-Info.plist updated in iOS

### 2.2 Firestore Configuration
- [ ] Database created in Firestore (if not exists)
- [ ] Security rules allow read/write to users/{uid}/notifications
- [ ] Security rules allow read/write to users/{uid}/fcmToken

---

## 3. Unit Tests

### 3.1 NotificationModel Tests
- [ ] Test toFirestore() serialization
- [ ] Test fromFirestore() deserialization
- [ ] Test copyWith() method
- [ ] Test NotificationType enum values

### 3.2 NotificationService Tests
- [ ] Test singleton pattern
- [ ] Test initialize() method
- [ ] Test saveFCMTokenForUser() saves to Firestore
- [ ] Test sendLocalNotification() creates notification
- [ ] Test saveNotification() stores in Firestore

---

## 4. Manual Testing: Foreground Notifications

### 4.1 Setup
- [ ] Physical device connected (Android or iOS)
- [ ] App compiled and running in debug mode
- [ ] Logged in as customer
- [ ] FCM token visible in Firestore: users/{phoneNumber}/fcmToken

### 4.2 FCM Token Verification
- [ ] Open Firestore Console
- [ ] Navigate to users collection
- [ ] Find logged-in user document (phoneNumber)
- [ ] Verify fcmToken field exists and has value
- [ ] Verify notificationsEnabled is true (if field exists)

### 4.3 Order Creation
- [ ] Select products from home
- [ ] Add to cart
- [ ] Proceed to checkout
- [ ] Select pickup slot
- [ ] Complete payment
- [ ] Reach OrderSummaryScreen
- [ ] Note the order ID

### 4.4 Status Change Notification (Foreground)
- [ ] App is running and visible (foreground)
- [ ] Admin logs in (admin@smartshop.com / admin123)
- [ ] Navigate to Orders Management
- [ ] Find the order by ID
- [ ] Change status to "Confirmed"
- [ ] Click update button
- [ ] Within 5 seconds, check customer device
- [ ] Notification appears in notification tray
- [ ] Title: "✅ Order Confirmed"
- [ ] Body: "Your payment has been verified. Your order is confirmed!"

### 4.5 Notification Tray Check
- [ ] Notification taps navigate to OrderDetailScreen
- [ ] OrderDetailScreen shows correct orderId
- [ ] Order status is updated to "Confirmed"
- [ ] Status timeline shows correct progress

### 4.6 Notifications Screen
- [ ] Navigate to Notifications screen
- [ ] Order notification appears in list
- [ ] Title and body are correct
- [ ] Timestamp is recent
- [ ] Can swipe to delete notification
- [ ] Can tap notification to go to order detail

### 4.7 Multiple Status Changes (Foreground)
Test each status with notification appearing:

#### Update to "Preparing"
- [ ] Admin updates to "Preparing"
- [ ] Notification appears: "🍳 Preparing Your Order"
- [ ] Notification saved to Firestore

#### Update to "ReadyForPickup"
- [ ] Admin updates to "ReadyForPickup"
- [ ] Notification appears: "📦 Ready for Pickup!"
- [ ] Notification saved to Firestore

#### Update to "Completed"
- [ ] Admin updates to "Completed"
- [ ] Notification appears: "✓ Order Completed"
- [ ] Notification saved to Firestore

### 4.8 No Notification for PendingPayment
- [ ] Create new order, don't complete it (stays in pendingPayment)
- [ ] Verify no notification is sent for payment status updates

---

## 5. Manual Testing: Background Notifications

### 5.1 Setup
- [ ] App compiled and running
- [ ] Customer logged in with order created
- [ ] Admin logged in and ready to update order

### 5.2 App in Background
- [ ] Press home button to send app to background
- [ ] Verify app is not visible (but not terminated)
- [ ] Admin updates order status to "Confirmed"
- [ ] Look at device notification tray
- [ ] Notification appears with sound/vibration

### 5.3 Notification Tap (App in Background)
- [ ] Tap notification in notification tray
- [ ] App comes to foreground
- [ ] Navigates to OrderDetailScreen
- [ ] Order shows status "Confirmed"

### 5.4 Check Notification History
- [ ] Open NotificationsScreen
- [ ] Notification from background is listed
- [ ] Can be marked as read

---

## 6. Manual Testing: App Closed (Cold Start)

### 6.1 Setup
- [ ] Create and log in with order (foreground)
- [ ] Admin has login credentials ready

### 6.2 App Closed
- [ ] Swipe away app to fully close it
- [ ] Verify app is not running (check device task manager)
- [ ] Admin updates order status to "Preparing"
- [ ] Look at device notification center
- [ ] Notification appears (may show in lock screen too)

### 6.3 Notification Tap (App Closed)
- [ ] Tap notification from lock screen or notification center
- [ ] App starts from scratch (cold start)
- [ ] Firebase initialization happens
- [ ] Navigates to OrderDetailScreen
- [ ] Shows correct orderId
- [ ] Order status shows "Preparing"

### 6.4 Verify Firestore Updated
- [ ] Open Firestore Console
- [ ] users/{phoneNumber}/notifications should have new notification
- [ ] Check that notification document has orderId and correct status

---

## 7. Error Scenarios

### 7.1 Network Issues
- [ ] Turn off WiFi and mobile data
- [ ] Attempt to update order status
- [ ] Turn network back on
- [ ] Verify notification is still saved to Firestore
- [ ] NotificationsScreen still shows notification

### 7.2 Permission Denied (iOS)
- [ ] Go to Settings → Notifications → [App]
- [ ] Disable notification permission
- [ ] Admin updates order status
- [ ] Local notification doesn't appear
- [ ] Verify notification is still saved to Firestore
- [ ] Check NotificationsScreen (should show notification)

### 7.3 Multiple Users
- [ ] Login as customer 1 (+91 XXXXXXXX01)
- [ ] Create and place order
- [ ] Login as customer 2 (+91 XXXXXXXX02) in different device
- [ ] Create and place order
- [ ] Admin updates customer 1's order
- [ ] Customer 1 receives notification
- [ ] Customer 2 does NOT receive notification

### 7.4 Token Refresh
- [ ] Login as customer
- [ ] Note FCM token in Firestore
- [ ] Uninstall and reinstall app
- [ ] Login again
- [ ] New FCM token is generated and saved
- [ ] Verify token in Firestore is updated

---

## 8. UI/UX Tests

### 8.1 Notifications Screen
- [ ] Layout looks clean and professional
- [ ] List items show title, body, timestamp
- [ ] Colored left border indicates status
- [ ] Can scroll through many notifications
- [ ] Empty state shown when no notifications
- [ ] Loading spinner shown while fetching

### 8.2 Notification Cards
- [ ] Title is bold for unread, normal for read
- [ ] Background is light blue for unread
- [ ] Status color matches order status (green, blue, red, etc.)
- [ ] Tap navigates to order detail
- [ ] Tap marks notification as read

### 8.3 Delete Functionality
- [ ] Long press or tap menu button on notification
- [ ] Delete option appears
- [ ] Confirm delete
- [ ] Notification removed from list
- [ ] Notification removed from Firestore

### 8.4 Local Notification Display
- [ ] Notification title is clear and concise
- [ ] Body text is readable
- [ ] Sound/vibration works
- [ ] Notification color matches app theme
- [ ] Notification dismisses properly

---

## 9. Performance Tests

### 9.1 Message Handling Speed
- [ ] Admin updates order status
- [ ] Notification appears within 2-3 seconds
- [ ] No app freezing or lag
- [ ] Device remains responsive

### 9.2 Notification History Loading
- [ ] Open NotificationsScreen with 10+ notifications
- [ ] List loads smoothly
- [ ] Scrolling is smooth
- [ ] No jank or frame drops

### 9.3 Real-time Updates
- [ ] Open NotificationsScreen
- [ ] Have admin send notification in another device
- [ ] New notification appears instantly in list
- [ ] No need to refresh

---

## 10. Security Tests

### 10.1 Token Security
- [ ] FCM token not logged in production builds
- [ ] Token stored only in Firestore (not SharedPreferences)
- [ ] Token only accessible to that user

### 10.2 Firestore Security Rules
- [ ] Users can only read/write their own notifications
- [ ] Try to access user2's notifications as user1
- [ ] Request denied (security rules enforced)

### 10.3 Notification Content
- [ ] No sensitive data in notification title
- [ ] Body contains only order-related info
- [ ] No personal information leaked in payload

---

## 11. Integration Tests

### 11.1 End-to-End Flow
- [ ] Customer login
- [ ] Product selection
- [ ] Cart management
- [ ] Checkout and payment
- [ ] Order creation
- [ ] Admin status update
- [ ] Customer receives notification
- [ ] Notification click navigates correctly

### 11.2 Multi-Device Testing
- [ ] Customer logs in on device 1
- [ ] Creates order
- [ ] Receives notification on device 1
- [ ] Customer logs in on device 2 (same phone number)
- [ ] New FCM token saved for device 2
- [ ] Old device 1 no longer receives notifications
- [ ] Device 2 receives new notifications

### 11.3 Session Persistence
- [ ] Customer logs in
- [ ] Kill app process
- [ ] Reopen app
- [ ] Still logged in
- [ ] Can receive notifications

---

## 12. Compatibility Tests

### 12.1 Android Testing
- [ ] Android 8+ supports notifications
- [ ] Android 11+ supports custom notification colors
- [ ] Notifications appear in notification panel
- [ ] Can dismiss notifications
- [ ] Can open app from notification

### 12.2 iOS Testing
- [ ] iOS 13+ supports notifications
- [ ] Notifications appear in lock screen
- [ ] Notifications appear in notification center
- [ ] Sound and haptic feedback works
- [ ] VoIP push (if using critical alerts)

### 12.3 Tablet Testing
- [ ] Notifications display properly on larger screens
- [ ] Landscape orientation works
- [ ] Notification taps navigate correctly

---

## 13. Documentation Tests

### 13.1 Code Documentation
- [ ] All public methods have docstrings
- [ ] Code comments explain complex logic
- [ ] Error messages are helpful

### 13.2 README/Guide
- [ ] Push Notifications Guide created
- [ ] Architecture explained clearly
- [ ] Testing instructions provided
- [ ] Troubleshooting guide included

---

## 14. Final Verification

### 14.1 Code Quality
- [ ] No compilation errors: `flutter analyze`
- [ ] Code follows Dart style guide
- [ ] No unused imports
- [ ] No hardcoded strings (use constants)

### 14.2 Git Commits
- [ ] All changes committed with clear messages
- [ ] Commits logically grouped
- [ ] No uncommitted changes

### 14.3 Version Compatibility
- [ ] Tested on Flutter 3.x
- [ ] Tested on iOS 13+
- [ ] Tested on Android 8+
- [ ] All dependencies up to date

### 14.4 Cleanup
- [ ] Removed debug logging (or marked as debug only)
- [ ] Removed TODO comments (or converted to proper issues)
- [ ] Removed temporary test data
- [ ] Production build completes without warnings

---

## Summary

### Tests Completed
- [ ] Development Setup: __/__
- [ ] Firebase Configuration: __/__
- [ ] Unit Tests: __/__
- [ ] Foreground Notifications: __/__
- [ ] Background Notifications: __/__
- [ ] Cold Start (App Closed): __/__
- [ ] Error Scenarios: __/__
- [ ] UI/UX: __/__
- [ ] Performance: __/__
- [ ] Security: __/__
- [ ] Integration: __/__
- [ ] Compatibility: __/__
- [ ] Documentation: __/__
- [ ] Final Verification: __/__

### Known Issues
(List any issues found and their resolution status)

1. Issue: ____________
   Status: [ ] Open [ ] In Progress [ ] Resolved
   Resolution: ____________

### Test Sign-Off
- Tester: ____________
- Date: ____________
- Overall Status: [ ] PASSED [ ] PASSED WITH ISSUES [ ] FAILED

---

## Quick Reference Commands

### Build and Run
```bash
flutter clean
flutter pub get
flutter run
```

### Run Tests
```bash
flutter test test/
```

### Check Code Quality
```bash
flutter analyze
dart format lib/
```

### Monitor Logs
```bash
flutter logs | grep "Notification\|FCM"
```

### Firebase Emulator (Optional)
```bash
firebase emulators:start
```

---

## Next Phase
Once Phase 3 (Push Notifications) is complete:
1. **Phase 4:** Admin analytics dashboard
2. **Phase 5:** Advanced features (wishlists, reviews, promotions)
3. **Phase 6:** Production deployment

---

Last Updated: [Current Date]
Tested on: [Device/OS versions used]
