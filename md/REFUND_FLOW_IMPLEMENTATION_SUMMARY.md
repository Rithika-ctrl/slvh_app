# Refund Flow After Payment Rejection - Implementation Summary

## Quick Overview

✅ **Status**: COMPLETE & READY FOR TESTING

When a vendor rejects a payment screenshot, the system:
1. Sends instant FCM notification to customer
2. Shows "Payment Rejected" banner in order details
3. Provides refund instructions screen with:
   - Rejection reason
   - Refund timeline (5-7 business days)
   - Shop contact options
   - Option to retry payment

---

## What Was Implemented

### 1. Core Service: PaymentRejectionService
**File**: `lib/features/payments/services/payment_rejection_service.dart`

**Key Method**:
```dart
Future<PaymentModel> rejectPayment({
  required String paymentId,
  required String orderId,
  required String rejectionReason,
  required String customerPhone,
})
```

**What it does**:
- Updates `payments/{id}.status = 'rejected'`
- Stores `rejectionReason` for display
- Updates `orders/{id}.status = 'paymentRejected'`
- Sends FCM notification to customer
- All changes atomic (succeed/fail together)

### 2. UI Screen: RefundInstructionsScreen
**File**: `lib/features/payments/screens/refund_instructions_screen.dart`

Shows:
- 🔴 Rejection header with reason
- 📅 3-step refund process timeline
- 💳 Payment details (expandable)
- 📞 Contact support options (WhatsApp, Phone, Email)
- 🔄 Actions (Retry Payment, View Order)

### 3. OrderDetailScreen Integration
**File**: `lib/features/orders/screens/order_detail_screen.dart`

**Changes**:
- Shows red "Payment Rejected" banner when status = 'paymentRejected'
- Real-time watcher for rejected payment details
- "View Refund Instructions" button navigates to refund screen

### 4. OrderStatus Enum
**File**: `lib/features/orders/models/order_model.dart`

**Added**:
- `paymentRejected('Payment Rejected')` status
- Color: Red (error state)

### 5. Firestore Rules
**File**: `firestore.rules`

**Permission**:
- Admin can update payment status to 'rejected'
- Includes rejectionReason field

---

## User Experience Flow

```
Admin rejects payment with reason "Blurry image"
    ↓
Atomic update:
- payments/{id}.status = 'rejected'
- payments/{id}.rejectionReason = 'Blurry image'
- orders/{id}.status = 'paymentRejected'
    ↓
Customer receives FCM notification:
"❌ Payment Rejected - Your payment for order X was rejected: Blurry image"
    ↓
Customer opens app → Order Detail Screen
    ↓
Sees red banner: "Payment Rejected - Blurry image"
Button: "View Refund Instructions"
    ↓
Taps button → RefundInstructionsScreen
    ↓
Sees:
- Why rejected: "Blurry image"
- What happens: "Refund in 5-7 business days automatically"
- No action needed
- Contact support if needed: WhatsApp, Phone, Email
    ↓
Options:
A) "Retry Payment" → Go back to payment screen
B) "View Order" → Back to order details
C) "Contact Support" → WhatsApp/Phone/Email
```

---

## Files Created (2)

| File | Lines | Purpose |
|------|-------|---------|
| `payment_rejection_service.dart` | ~180 | Rejection logic + notifications |
| `refund_instructions_screen.dart` | ~420 | Refund UI + contact options |

## Files Modified (3)

| File | Changes | Type |
|------|---------|------|
| `order_detail_screen.dart` | +imports, +rejection notice, +refund nav | Integration |
| `order_model.dart` | Added `paymentRejected` status | Model |
| `firestore.rules` | Admin rejection permission | Rules |

---

## Database Changes

### Payments Collection
```
payments/{paymentId}
├── status: 'rejected'              // NEW value
├── rejectionReason: 'Blurry...'    // NEW field
├── updatedAt: <timestamp>
└── (other fields unchanged)
```

### Orders Collection
```
orders/{orderId}
├── status: 'paymentRejected'       // NEW value
├── updatedAt: <timestamp>
└── (other fields unchanged)
```

---

## Testing Quick Steps

### Manual Test (5 minutes)

1. **Admin Rejects Payment**
   - In Firestore console: Update a pending payment
   - Set `status = 'rejected'`
   - Set `rejectionReason = 'Test rejection'`
   - Also update related order `status = 'paymentRejected'`

2. **Customer Opens Order Detail**
   - Open app
   - Go to order history
   - Select order with rejected payment
   - ✅ See red "Payment Rejected" banner
   - ✅ See rejection reason displayed
   - ✅ See "View Refund Instructions" button

3. **View Refund Instructions**
   - Tap "View Refund Instructions"
   - ✅ See rejection header
   - ✅ See reason: "Test rejection"
   - ✅ See 3-step refund timeline
   - ✅ See "Retry Payment" and "View Order" buttons
   - Tap "View Order" → Back to order detail

4. **Verify Firestore**
   - Check `payments/{id}`:
     - ✅ `status = 'rejected'`
     - ✅ `rejectionReason = 'Test rejection'`
   - Check `orders/{id}`:
     - ✅ `status = 'paymentRejected'`

---

## Integration Points

### With Existing Features

1. **Order Service**
   - Order status transitions: paymentVerificationPending → paymentRejected

2. **Notification Service**
   - Sends FCM notification on rejection
   - Saves to notification history

3. **Order Detail Screen**
   - Now shows rejection notice
   - Navigates to refund instructions

4. **Payment Service**
   - `rejectPayment()` method already exists (from earlier implementation)
   - This feature complements it with UI + notifications

---

## Key Implementation Details

### Atomic Batch Write

Ensures consistency if either operation fails:

```dart
final batch = _firestore.batch();

// Update payment
batch.update(paymentRef, {
  'status': 'rejected',
  'rejectionReason': rejectionReason,
  'updatedAt': DateTime.now(),
});

// Update order
batch.update(orderRef, {
  'status': 'paymentRejected',
  'updatedAt': DateTime.now(),
});

// All-or-nothing
await batch.commit();
```

### Real-time Updates

RefundInstructionsScreen watches for rejection details:

```dart
Stream<PaymentModel?> watchRejectedPaymentByOrderId(String orderId)
```

UI auto-updates if rejection details change.

### Contact Launchers

Refund screen includes one-tap contact:
- WhatsApp: Opens chat with shop
- Phone: Opens phone dialer
- Email: Opens email client

---

## Security

### Firestore Rules
- Only admin/cloud functions can reject payments
- Users cannot modify their payment status
- Users can read their own payments

### Data Validation
- Rejection reason required (prevents empty rejections)
- Payment ID and order ID must exist
- Customer phone for notification validation

---

## Monitoring

### Track These Metrics

1. **Rejection Rate**
   - How many payments are rejected
   - Rejection rate trend
   - Most common reasons

2. **Customer Response**
   - How many customers view refund instructions
   - How many retry after rejection
   - Time to retry

3. **Support Load**
   - How many contact support via WhatsApp/Phone
   - Common support questions about refunds

---

## Deployment Checklist

- [ ] Code review of rejection service and screen
- [ ] Deploy Firestore rules: `firebase deploy --only firestore:rules`
- [ ] Test on staging environment
- [ ] Verify FCM notifications work
- [ ] Test all contact methods (WhatsApp, Phone, Email)
- [ ] QA approval
- [ ] Deploy to production

---

## Future Enhancements (Phase 2)

1. **Auto-refunds**: Trigger bank transfer automatically
2. **Admin Dashboard**: Reject button in verification list
3. **Appeal Process**: Customer can appeal rejections
4. **Smart Suggestions**: AI suggests better screenshots
5. **Refund Tracking**: Customer sees refund progress

---

## Code Locations

✓ Service Logic
  └─ lib/features/payments/services/payment_rejection_service.dart

✓ UI Screen
  └─ lib/features/payments/screens/refund_instructions_screen.dart

✓ Integration
  └─ lib/features/orders/screens/order_detail_screen.dart

✓ Data Model
  └─ lib/features/orders/models/order_model.dart (paymentRejected status)

✓ Security Rules
  └─ firestore.rules (rejection permission)

---

**Status**: ✅ COMPLETE & READY FOR QA
**Implementation Date**: Phase 1 MVP
**Testing Ready**: Yes
**Documentation**: Complete
