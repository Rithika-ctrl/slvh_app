# Screenshot Rejection Reasons - Implementation Guide

## Feature Overview

When admin rejects payment screenshot, they **select from predefined reasons** and customer receives:
- WhatsApp notification with reason + refund instructions
- Order detail shows reason for rejection
- Clear guidance on what to fix or resubmit

**Status**: ✅ MVP Phase 1 Complete

---

## What's Implemented

### 1. Admin Rejection Dialog
**File**: `lib/features/payments/dialogs/admin_rejection_dialog.dart`

```dart
AdminRejectionDialog(
  payment: payment,
  onConfirm: (reason) => rejectPayment(reason),
)
```

**UI**:
- Dropdown with 6 predefined reasons
- Warning: "Reason will be sent to customer via WhatsApp"
- Loading state during rejection
- Confirm/Cancel buttons

**Predefined Reasons**:
- Screenshot blurry or unclear
- Payment amount mismatch
- Wrong UPI ID used
- Payment reference not visible
- Transaction time not visible
- Screenshot appears edited

### 2. Enhanced PaymentRejectionService
**File**: `lib/features/payments/services/payment_rejection_service.dart`

**Methods**:
- `rejectPayment()`: Atomic update + notifications
- `_sendWhatsAppNotification()`: Sends reason via WhatsApp (Cloud Function ready)
- Returns rejection reason to customer

### 3. RefundInstructionsScreen
**File**: `lib/features/payments/screens/refund_instructions_screen.dart`

Already displays rejection reason:
- Card shows: "Reason for Rejection"
- Displays selected reason (e.g., "Screenshot blurry")
- Helps customer understand what went wrong

---

## Database Structure

```
payments/{id}
├── status: 'rejected'
├── rejectionReason: 'Screenshot blurry'  ← User selects from dropdown
├── updatedAt: timestamp
└── (other fields)

orders/{id}
├── status: 'paymentRejected'
└── updatedAt: timestamp
```

---

## Flow Diagram

```
Admin Dashboard → Pending Verifications
    ↓
Admin clicks "Reject" on payment
    ↓
AdminRejectionDialog opens
    ↓
Admin selects reason: "Screenshot blurry"
    ↓
Admin clicks "Reject Payment"
    ↓
Atomic Updates:
├─ payments.status = 'rejected'
├─ payments.rejectionReason = 'Screenshot blurry'
├─ orders.status = 'paymentRejected'
└─ Send notifications:
   ├─ FCM: "❌ Payment Rejected - Screenshot blurry"
   ├─ WhatsApp: "🔴 Payment Rejected - Reason: Screenshot blurry"
   └─ Notification History: Save for customer records

Customer Opens Order:
├─ Sees red "Payment Rejected" banner
├─ Reason: "Screenshot blurry"
├─ Taps "View Refund Instructions"
│   └─ RefundInstructionsScreen shows reason + what to do
└─ Options: Retry Payment (with better screenshot) or Contact Support
```

---

## User Experience

### For Admin
1. Open pending verifications
2. Click "Reject" button on payment
3. AdminRejectionDialog appears
4. Select reason from dropdown: "Screenshot blurry"
5. Click "Reject Payment"
6. Success message shows
7. Reason automatically sent to customer

### For Customer
1. Receives WhatsApp: "Payment Rejected - Reason: Screenshot blurry"
2. Opens order detail
3. Sees: "Why was it rejected? Screenshot blurry"
4. Reads refund instructions
5. Knows what to fix: "Use better lighting, clearer image"
6. Can retry payment with correct screenshot

---

## Implementation Checklist

- [x] AdminRejectionDialog created with dropdown
- [x] 6 predefined rejection reasons
- [x] PaymentRejectionService sends WhatsApp notification
- [x] WhatsApp message includes rejection reason
- [x] RefundInstructionsScreen displays reason
- [x] OrderDetailScreen shows rejection reason
- [x] Database: rejectionReason field stored

---

## Rejection Reasons (Predefined)

| Reason | What Customer Should Do |
|--------|------------------------|
| Screenshot blurry or unclear | Use better lighting, take clearer photo |
| Payment amount mismatch | Check amount matches order total |
| Wrong UPI ID used | Use correct shop UPI ID |
| Payment reference not visible | Ensure transaction ID is clear |
| Transaction time not visible | Show complete timestamp |
| Screenshot appears edited | Submit original unedited screenshot |

---

## Testing Checklist

- [ ] AdminRejectionDialog opens when admin clicks "Reject"
- [ ] Dropdown shows all 6 reasons
- [ ] Selected reason is stored in payments document
- [ ] Order status changes to 'paymentRejected'
- [ ] Customer receives WhatsApp notification
- [ ] WhatsApp message includes reason
- [ ] RefundInstructionsScreen displays reason
- [ ] OrderDetailScreen banner shows reason
- [ ] Customer can retry payment from refund screen

---

## Firestore Rules

```firestore
match /payments/{paymentId} {
  // Admin can update payment status + rejection reason
  allow update: if isAdmin() || isCloudFunction();
}
```

---

## Code Usage

### For Admin Rejection (Dashboard)
```dart
// Show rejection dialog
showDialog(
  context: context,
  builder: (context) => AdminRejectionDialog(
    payment: payment,
    onConfirm: (reason) async {
      await PaymentRejectionService().rejectPayment(
        paymentId: payment.id,
        orderId: payment.orderId,
        rejectionReason: reason,
        customerPhone: payment.customerPhone,
      );
    },
  ),
);
```

### For Customer View
```dart
// Already integrated in OrderDetailScreen
// Shows rejection reason in:
// 1. Red banner: "Payment Rejected - {reason}"
// 2. RefundInstructionsScreen: "Reason for Rejection: {reason}"
```

---

## WhatsApp Notification (Production)

Message sent to customer:

```
🔴 Payment Rejected - Order #order_123

Reason: Screenshot blurry or unclear

Your payment screenshot was not accepted. Here's what to do:

1️⃣ A refund will be automatically processed (5-7 days)
2️⃣ You'll receive a notification when refund is complete
3️⃣ You can retry payment in the app with a clearer screenshot

Open the app to view refund instructions.

Need help? Reply to this message or contact support.
```

---

## Future Enhancements

1. **Custom Reasons**: Admin can add custom rejection reasons
2. **Auto-suggestions**: System suggests reason based on image analysis
3. **Appeal Process**: Customer can appeal rejection with better screenshot
4. **Analytics**: Track most common rejection reasons
5. **Bulk Reject**: Reject multiple payments with same reason

---

## Files Modified/Created

| File | Changes | Type |
|------|---------|------|
| `admin_rejection_dialog.dart` | New: Dropdown dialog for reasons | Widget |
| `payment_rejection_service.dart` | Enhanced: WhatsApp notification | Service |
| `refund_instructions_screen.dart` | No changes (already displays reason) | Screen |
| `order_detail_screen.dart` | No changes (already displays reason) | Screen |

---

## FAQ

**Q: Can customer see rejection reason?**
A: Yes. Reason shown in: (1) WhatsApp message, (2) Order detail banner, (3) Refund instructions screen.

**Q: Can customer add custom reason?**
A: No. Admin selects from 6 predefined reasons. Custom reasons may be added in Phase 2.

**Q: What if reason doesn't fit?**
A: Email support with custom reason, or select closest match.

**Q: Does WhatsApp send immediately?**
A: In production, Cloud Function sends via WhatsApp Business API. FCM is instant.

**Q: Can customer see past rejection reasons?**
A: Yes. Order detail shows all rejection reasons, and notification history saves them.

---

**Status**: ✅ COMPLETE & READY FOR TESTING
