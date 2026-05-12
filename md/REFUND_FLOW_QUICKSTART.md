# Refund Flow - Quick Start (5 Minutes)

## What Happens

1. Admin rejects payment with reason
2. Customer gets notification immediately
3. Order detail shows red "Payment Rejected" banner
4. "View Refund Instructions" shows refund timeline
5. Customer can retry payment or contact support

---

## Testing Flow (5 Minutes)

### Step 1: Trigger Rejection
```
Firestore Console → payments/{paymentId}
├── Set: status = 'rejected'
├── Set: rejectionReason = 'Blurry screenshot'
└── Save

Firestore Console → orders/{orderId}
├── Set: status = 'paymentRejected'
└── Save
```

### Step 2: See Customer Notification
1. Open app
2. See FCM notification: "❌ Payment Rejected"
3. Includes rejection reason

### Step 3: View Order Detail
1. Go to order history
2. Tap the rejected order
3. ✅ See red "Payment Rejected" banner
4. ✅ See reason: "Blurry screenshot"
5. ✅ See "View Refund Instructions" button

### Step 4: View Refund Instructions
1. Tap "View Refund Instructions"
2. ✅ See rejection header (red warning)
3. ✅ See reason displayed
4. ✅ See 3-step refund timeline:
   - 1️⃣ Automatic refund to original account
   - 2️⃣ 5-7 business days
   - 3️⃣ WhatsApp notification
5. ✅ See payment details (expandable)
6. ✅ See contact buttons (WhatsApp, Phone, Email)
7. ✅ See action buttons (Retry Payment, View Order)

### Step 5: Test Actions
1. Tap "View Order" → Back to order detail ✅
2. Go back, tap "Contact Support" → Opens options ✅
3. Go back, tap "Retry Payment" → Intent to retry ✅

---

## Files to Review (5 Minutes)

### 1. PaymentRejectionService
**File**: `lib/features/payments/services/payment_rejection_service.dart`

Core logic:
```dart
Future<PaymentModel> rejectPayment({
  required String paymentId,
  required String orderId,
  required String rejectionReason,
  required String customerPhone,
})
```

### 2. RefundInstructionsScreen
**File**: `lib/features/payments/screens/refund_instructions_screen.dart`

Shows refund timeline, contact, payment details:
```dart
RefundInstructionsScreen(
  order: order,
  payment: payment,
  onRetryPayment: () { ... }
)
```

### 3. OrderDetailScreen Enhancement
**File**: `lib/features/orders/screens/order_detail_screen.dart`

Watches for rejection:
```dart
if (order.status == OrderStatus.paymentRejected)
  _buildPaymentRejectionNotice(context, order)
```

### 4. New OrderStatus
**File**: `lib/features/orders/models/order_model.dart`

```dart
paymentRejected('Payment Rejected')  // Red status
```

---

## Key Flow

```
Admin Rejects
    ↓
Firestore Updates (atomic):
- payments.status = rejected
- orders.status = paymentRejected
    ↓
FCM Notification Sent
    ↓
Customer Opens Order
    ↓
Sees Red Banner + Button
    ↓
Views Refund Instructions
    ↓
Options: Retry, Contact, View Order
```

---

## What to Check

| Item | Expected | Status |
|------|----------|--------|
| Rejection reason stored | ✅ | |
| Order status updated | ✅ | |
| Customer notified | ✅ | |
| Red banner shown | ✅ | |
| Refund screen loads | ✅ | |
| Timeline shows | ✅ | |
| Contact buttons work | ✅ | |
| Retry button works | ✅ | |

---

## Common Issues

| Issue | Check |
|-------|-------|
| Banner not showing | Order status = 'paymentRejected'? |
| No notification | Notification service initialized? |
| Refund screen blank | Payment object loaded correctly? |
| Contact buttons broken | URLs valid? (WhatsApp, Phone, Email) |

---

## Database Structure

```
✅ payments/{id}
  - status: 'rejected'
  - rejectionReason: 'Blurry image'
  - updatedAt: timestamp

✅ orders/{id}
  - status: 'paymentRejected'
  - updatedAt: timestamp
```

---

## Next Steps

1. ✅ Code review
2. ✅ Deploy rules: `firebase deploy --only firestore:rules`
3. ✅ Test manually
4. ✅ QA approval
5. ✅ Production deployment

---

See full guide: [REFUND_FLOW_GUIDE.md](REFUND_FLOW_GUIDE.md)
