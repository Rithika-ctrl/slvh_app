# Payment Failure & Retry Flow - Implementation Guide

## Overview

The Payment Failure & Retry Flow handles the scenario where a customer has successfully paid but the payment proof upload fails due to network or system issues. This ensures no orders are lost and provides a seamless recovery mechanism.

## Key Components

### 1. **OrderModel Updates**
- **New Fields:**
  - `paymentRetryPending`: New order status for orders awaiting payment proof retry
  - `paymentReference`: Transaction/payment ID for retry tracking
  - `retryCount`: Number of retry attempts made
  - `lastRetryAt`: Timestamp of last retry attempt

### 2. **PaymentRetryService** (`payment_retry_service.dart`)
Handles draft order management and retry logic:
- `saveDraftOrder()`: Save order when upload fails
- `getPendingRetryOrders()`: Fetch orders awaiting retry
- `markRetryAttempt()`: Track retry attempts
- `finalizeDraftOrder()`: Complete order after successful retry
- `cancelDraftOrder()`: Allow user to cancel draft
- `canRetryAgain()`: Rate limiting (min 10 sec between retries)

### 3. **PaymentRetryBottomSheet** (`payment_retry_bottom_sheet.dart`)
UI shown when payment upload fails:
- **Retry Upload**: Resume upload without double charging
- **Continue Later**: Save order for later completion
- **Contact Support**: Reach out for help
- Shows retry count and order details
- Rate limiting to prevent spam retries

### 4. **PaymentService Updates** (`payment_service.dart`)
New methods for retry handling:
- `handlePaymentUploadFailure()`: Mark payment for retry
- `updateOrderFromRetryToVerification()`: Complete retry flow

### 5. **Payment Retry Provider** (`payment_retry_provider.dart`)
Riverpod providers for state management:
- `currentUserPendingRetryOrdersProvider`: Stream of pending orders
- `PaymentRetryRecoveryService`: Utility service for app startup checks

### 6. **PendingRetryOrdersDialog** (`pending_retry_orders_dialog.dart`)
Dialog shown on app startup if user has pending orders:
- Shows count of pending orders
- Details of oldest order
- Quick action to retry or dismiss

## Flow Diagrams

### Successful Payment Scenario
```
User selects payment → Payment processed → Screenshot upload → Success
                                                   ↓
                                         Order Status: paymentVerificationPending
```

### Payment Failure Scenario
```
User selects payment → Payment processed → Screenshot upload FAILS
                                          ↓
                         Save Draft Order with status: paymentRetryPending
                                          ↓
                         Show PaymentRetryBottomSheet with options:
                         - Retry Upload
                         - Continue Later
                         - Contact Support
                                          ↓
                                    User Actions:
                    Retry → Re-upload → Success/Failure
                    Later  → Save & Exit → Check on App Startup
                    Support → Contact us
```

### App Startup Recovery
```
App Launches → Check for pending retry orders
              ↓
         Orders Found? → Show PendingRetryOrdersDialog
         ↓                ↓
      No            User taps Retry → Navigate to Payment Screen
                     User taps Later → Dismiss dialog
```

## Database Schema Changes

### Firestore - Orders Collection
New fields added to order documents:

```firestore
orders/{orderId}
├── customerId: string
├── items: array
├── status: string (e.g., "paymentRetryPending")
├── paymentId: string
├── paymentStatus: string
├── paymentReference: string          # NEW: Transaction/payment ID
├── retryCount: integer               # NEW: Number of retries (starts at 0)
├── pickupDate: string
├── pickupTime: string
├── pickupSlotId: string
├── createdAt: timestamp
├── updatedAt: timestamp
├── lastRetryAt: timestamp            # NEW: When last retry was attempted
└── completedAt: timestamp
```

## Firestore Security Rules

Updated rules allow users to update their own draft orders:

```firestore
match /orders/{orderId} {
  // Users can read their own orders
  allow read: if resource.data.customerId == request.auth.token.phone_number;
  
  // Admin can read all orders
  allow read: if isAdmin();
  
  // Cloud Functions can read orders
  allow read: if isCloudFunction();
  
  // Users can create orders (including drafts)
  allow create: if request.auth.token.phone_number != null;
  
  // Users can update their own draft orders
  allow update: if resource.data.customerId == request.auth.token.phone_number &&
                   resource.data.status == 'paymentRetryPending';
  
  // Admin and Cloud Functions can update any order
  allow update: if isAdmin() || isCloudFunction();
}
```

## Integration Points

### 1. **CheckoutScreen**
Pass OrderModel to PaymentScreen for draft creation:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PaymentScreen(
      orderId: orderId,
      amount: order.total,
      customerPhone: currentUser.phoneNumber ?? '',
      cartSummary: widget.cartSummary,
      orderModel: order.copyWith(id: orderId),  // NEW: Pass order object
    ),
  ),
);
```

### 2. **PaymentScreen**
Handle upload failure with retry UI:

```dart
catch (e) {
  // Payment succeeded but upload failed
  await _handleUploadFailure(e);
}
```

### 3. **App Initialization** (In main.dart or home screen)
Check for pending orders on startup:

```dart
Future<void> _checkPendingRetryOrders() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  final phoneNumber = currentUser.phoneNumber ?? '';
  final recoveryService = PaymentRetryRecoveryService();
  
  final pendingOrders = await recoveryService.getPendingRetryOrders(phoneNumber);
  
  if (pendingOrders.isNotEmpty && mounted) {
    showPendingRetryOrdersDialog(
      context,
      pendingOrders: pendingOrders,
      onRetry: () {
        // Navigate to payment retry screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              orderId: pendingOrders.first.id,
              amount: pendingOrders.first.total,
              customerPhone: phoneNumber,
              orderModel: pendingOrders.first,
            ),
          ),
        );
      },
    );
  }
}
```

## User Experience

### Scenario 1: Payment Upload Succeeds
1. User scans QR and pays
2. User uploads screenshot
3. Screenshot upload completes → Order confirmed → Success message
4. Automatic navigation to order summary

### Scenario 2: Payment Upload Fails
1. User scans QR and pays ✅
2. User uploads screenshot ❌ (network error)
3. PaymentRetryBottomSheet appears with options:
   - **Retry Upload**: Upload image again (rate limited to 10+ seconds)
   - **Continue Later**: Save order, close payment screen
   - **Contact Support**: Open support contact options
4. If Retry → Same as Scenario 1
5. If Later → App shows badge/notification about pending order

### Scenario 3: App Restart with Pending Order
1. User had pending order, closed app
2. App restarts
3. PendingRetryOrdersDialog appears showing:
   - Number of pending orders
   - Details of oldest order
   - Buttons: "Later" or "Retry Upload"
4. User can proceed to retry

## Rate Limiting

- Minimum 10 seconds between retry attempts
- Prevents accidental double uploads or spam
- Message shown if user tries to retry too quickly

## Error Handling

### Network Failures
- Screenshot upload timeout → Draft order saved → Retry UI shown
- Firestore write failure → Error message, offer retry

### Stock Management
- Stock reduced ONLY after successful payment verification
- Draft orders don't reduce stock
- If draft is cancelled → Stock remains unchanged

### Idempotency
- Payment reference stored to prevent double charging
- Retry uses same payment ID (no new charge)
- Order ID remains same throughout retry process

## Frontend Implementation Checklist

- [x] Update OrderModel with new fields
- [x] Add paymentRetryPending status to OrderStatus enum
- [x] Create PaymentRetryService
- [x] Create PaymentRetryBottomSheet UI
- [x] Update PaymentScreen to handle failures
- [x] Update PaymentService with retry methods
- [x] Create PaymentRetryProvider
- [x] Create PendingRetryOrdersDialog
- [x] Update CheckoutScreen to pass order object
- [ ] Update main.dart/home screen to check for pending orders on startup
- [ ] Add notification badge/counter for pending orders
- [ ] Test end-to-end flow

## Testing Checklist

### Manual Testing
1. Simulate upload failure (unplug internet) → Verify draft order created
2. Tap "Retry Upload" → Verify retry counter increments
3. Close and restart app → Verify pending order dialog shown
4. Tap "Retry Upload" from dialog → Verify order completes
5. Network reconnected → Verify upload succeeds

### Edge Cases
1. Multiple retries with rate limiting
2. User cancels draft order → Verify it moves to cancelled status
3. User closes app mid-upload → Verify draft is saved
4. Verify stock is not reduced for draft orders
5. Verify payment is not double-charged on retry

## Notes

- Draft orders are stored in same collection as regular orders
- Stock reduction happens ONLY after payment verification
- Payment reference (paymentId) ensures no double charging
- All timestamps tracked for admin analytics
- Future: Can add automatic retry scheduler for abandoned orders
- Future: Can add push notification for pending orders

## Related Documentation

- [PAYMENT_MODULE_GUIDE.md](PAYMENT_MODULE_GUIDE.md) - Overall payment flow
- [ORDER_CREATION_GUIDE.md](ORDER_CREATION_GUIDE.md) - Order lifecycle
- [CHECKOUT_FLOW_INTEGRATION.md](CHECKOUT_FLOW_INTEGRATION.md) - Checkout integration
