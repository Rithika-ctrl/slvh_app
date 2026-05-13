# Admin FCM Push Notification Implementation Guide

## Overview
This feature enables the admin (vendor) to receive instant Firebase Cloud Messaging (FCM) push notifications whenever a new order is created by a customer. This solves the problem of delayed order verification and keeps the vendor informed in real-time.

## Architecture

### Data Flow
```
Customer Creates Order → Firestore onCreate Trigger
                       ↓
                   Cloud Function: onOrderCreate
                       ↓
                   Query: Find admin user (role: "admin")
                       ↓
                   Get admin's FCM token from users/{adminId}
                       ↓
                   Send FCM push notification
                       ↓
                   Log to fcm_notifications_log
```

## Implementation Details

### 1. Admin Profile Storage

**Location**: `users/{adminId}` (Firestore)

**Admin Profile Schema**:
```json
{
  "role": "admin",
  "email": "admin@smartshop.com",
  "phone": "+919999999999",  // Optional: for backup contact
  "fcmToken": "exOc4oM0...",  // Firebase Cloud Messaging device token
  "updatedAt": "2026-05-13T10:30:00Z"
}
```

**Document ID Options**:
- **Recommended**: Use `"admin"` as the fixed document ID
- Alternative: Use email or phone as document ID

### 2. Admin Login Flow (Updated)

When admin logs in via `adminLogin()`:
1. Authenticate with email/password
2. Check if email is in admin whitelist
3. **Save admin session** (stores email and admin login flag)
4. **Save FCM token** to `users/admin` document (NEW)

### 3. Cloud Function: onOrderCreate

**Trigger**: `onCreate` event on `orders/{orderId}`

**Logic**:
```typescript
onOrderCreate:
  1. Extract order data (customerId, total, items.length)
  2. Fetch customer name from users/{customerId}
  3. Find admin user by querying users where role == "admin"
  4. Get admin's FCM token
  5. Send FCM notification via admin.messaging().send()
  6. Log to fcm_notifications_log for audit trail
  7. Return success/error status
```

**Notification Payload**:
```json
{
  "title": "🆕 New Order Received!",
  "body": "Order ABC123 from John Doe - ₹2,499",
  "data": {
    "orderId": "ABC123",
    "customerId": "919999999999",
    "customerName": "John Doe",
    "total": "2499",
    "itemCount": "3",
    "notificationType": "new_order_alert"
  }
}
```

### 4. FCM Helper Functions

**Location**: `functions/src/notifications.ts`

#### `sendFCMNotification(fcmToken, params)`
Generic FCM push notification sender
- Input: FCM token, title, body, data
- Output: NotificationResult (success, messageId, error)
- Logs to `fcm_notifications_log`

#### `sendAdminNewOrderAlert(orderData)`
Specialized function for new order alerts
- Input: orderId, customerId, customerName, total, itemCount
- Queries for admin user by role
- Gets admin's FCM token
- Sends notification
- Returns: NotificationResult

### 5. Flutter Implementation (NotificationService)

**File**: `lib/features/notifications/services/notification_service.dart`

**Method**: `saveFCMTokenForUser(userId)`
- Already implemented and called on customer login
- On admin login, should be called with admin document ID (e.g., "admin")
- Saves FCM token to `users/{userId}/fcmToken`

### 6. Firestore Rules

**Collection**: `users/{phoneNumber}`

**Permissions**:
- Cloud Functions can read all user documents (to find admin)
- Cloud Functions can write FCM tokens for any user
- Admins can read/update their own fcmToken
- Customers can update their own fcmToken

**Current Rules** (Already sufficient):
```firestore
allow read: if isCloudFunction();
allow write: if isCloudFunction();  // Allows FCM token update
allow update: if isAdmin();         // Admin can update own data
allow update: if isPhoneOwner();    // Customer can update own data
```

## Testing Checklist

### Local Testing
- [ ] Cloud Functions deployed to Firebase (dev project)
- [ ] Test order creation in Firestore manually
- [ ] Check Cloud Function logs for errors
- [ ] Verify `fcm_notifications_log` collection has entries

### Firebase Console
- [ ] View onOrderCreate function logs
- [ ] Check function execution times and error rates
- [ ] Verify FCM token is stored in users/admin document
- [ ] No authentication errors in logs

### Manual Testing
- [ ] Create a test order via the Flutter app
- [ ] Admin should receive push notification within 5 seconds
- [ ] Notification contains correct order ID and customer name
- [ ] Tap notification navigates to order details (when implemented)

### Error Scenarios
- [ ] No admin user in database → Should log warning
- [ ] Admin has no FCM token → Should log error
- [ ] FCM token is invalid → Firebase API returns error
- [ ] Multiple admins → Notification sent to first admin found

## Firestore Collections

### New Collection: `fcm_notifications_log`
**Purpose**: Audit trail for all FCM notifications sent

**Schema**:
```json
{
  "fcmToken": "exOc4oM0... (truncated)",  // Privacy: store partial token
  "title": "🆕 New Order Received!",
  "body": "Order ABC123 from John Doe - ₹2,499",
  "orderId": "ABC123",
  "customerId": "919999999999",
  "status": "success",  // or "failed" or "error"
  "messageId": "abc123def456",  // Firebase message ID
  "error": null,  // Error message if failed
  "notificationType": "new_order_alert",
  "sentAt": "2026-05-13T10:35:22Z"
}
```

**Retention Policy**: Keep for 90 days (for debugging), then archive

## Phase & Status

- **Phase**: Phase 2 (Post-MVP Features)
- **Priority**: 🟠 IMPORTANT (Prevents customer dissatisfaction)
- **Status**: ✅ Implemented

## Dependencies

- Firebase Admin SDK (Node.js)
- Firebase Cloud Messaging (FCM)
- Firebase Firestore
- Flutter: `firebase_messaging` package
- Flutter: `flutter_local_notifications` package

## Troubleshooting

### Admin doesn't receive notification

1. **Check FCM token exists**:
   - Open Firestore Console
   - Go to `users/admin` document
   - Verify `fcmToken` field exists and is not empty

2. **Check admin user exists**:
   - Verify user document with `role: "admin"` exists
   - Check email field matches whitelist

3. **Check Cloud Function logs**:
   - Firebase Console → Cloud Functions → onOrderCreate
   - Look for error messages or warnings

4. **Check FCM credentials**:
   - Firebase project has FCM enabled
   - Service account credentials are valid

### FCM token is empty or null

- Admin hasn't opened the app after logging in
- NotificationService.saveFCMTokenForUser() wasn't called
- FCM initialization failed (check permissions)
- Device doesn't have Google Play Services (on Android)

### Notification received but with wrong content

- Check order data in Firestore
- Verify customer document exists
- Check notification payload in Cloud Function logs

## Migration Notes

### If adding to existing admin setup:
1. Create admin user document in Firestore (if doesn't exist)
2. Update admin to have `role: "admin"` field
3. Open admin Flutter app to generate and save FCM token
4. Verify FCM token in Firestore admin document
5. Test by creating new order

## Security Considerations

- ✅ Only Cloud Functions can query admin users (rules enforce)
- ✅ FCM tokens are only accessible to Cloud Functions and owner
- ✅ Admin FCM tokens not exposed in APIs or analytics
- ✅ Partial FCM token logged (for audit, not full token)
- ✅ No customer data in notification (only orderId and name)

## Future Enhancements

1. **Multiple Admins**: Support multiple admin users (send to all)
2. **Admin Preferences**: Let admin choose notification settings
3. **WhatsApp Fallback**: If FCM fails, send WhatsApp alert
4. **Admin Dashboard Alert**: Also show in-app alert on admin dashboard
5. **Notification History**: UI to view all admin notifications
