# Order Cancellation - Quick Start (5 Minutes)

## What Users See

1. Open an order (status: "Payment Verification Pending")
2. **Red "Cancel Order" button** appears at bottom
3. Tap button → Confirmation dialog with order details
4. Tap "Cancel Order" → ✅ Success message + back to history
5. Order now shows as "Cancelled"

---

## Files to Review (10 Lines Each)

### 1. OrderCancellationService
**File**: `lib/features/orders/services/order_cancellation_service.dart`

Core logic:
```dart
bool canCancelOrder(OrderModel order) =>
  order.status == OrderStatus.paymentVerificationPending;

Future<void> cancelOrder(String orderId) =>
  _orderService.cancelOrder(orderId);
```

### 2. CancelOrderDialog  
**File**: `lib/features/orders/widgets/cancel_order_dialog.dart`

Shows confirmation:
```dart
showDialog(
  context: context,
  builder: (context) => CancelOrderDialog(order: order),
);
```

### 3. OrderDetailScreen - Cancel Button
**File**: `lib/features/orders/screens/order_detail_screen.dart`

Shows button only when cancellable:
```dart
if (order.status == OrderStatus.paymentVerificationPending)
  _buildCancelOrderButton(context, order)
```

### 4. Firestore Rules
**File**: `firestore.rules`

Allows cancellation:
```firestore
allow update: if resource.data.status == 'paymentVerificationPending' &&
                 request.resource.data.status == 'cancelled';
```

---

## Testing in 5 Minutes

### Step 1: Create Test Order
1. Open app, go to checkout
2. Complete payment (test payment)
3. Order status: "Payment Verification Pending"

### Step 2: View Cancel Button
1. Tap "View Orders"
2. Tap the order
3. ✅ See red "Cancel Order" button

### Step 3: Cancel Order
1. Tap "Cancel Order"
2. Dialog appears with warning
3. Tap "Cancel Order" in dialog
4. ✅ See success message
5. ✅ Auto-back to order history
6. ✅ Order now shows as "Cancelled"

### Step 4: Verify in Firebase
1. Open Firebase Console
2. Go to `orders/{orderId}`
3. ✅ Check: `status: "cancelled"`
4. ✅ Check: `cancelledAt: <timestamp>`
5. Go to `products/{productId}`
6. ✅ Check: `stock` increased

---

## What Can Go Wrong

| Issue | Check |
|-------|-------|
| Button not visible | Is order status "Payment Verification Pending"? |
| Permission denied | Are Firestore rules deployed? Is user authenticated? |
| Stock not restored | Did batch write complete? Check Firestore console |
| Dialog not showing | Is dialog widget imported? Is context.mounted? |

---

## Code Locations

```
✓ Service Logic
  └─ lib/features/orders/services/order_cancellation_service.dart

✓ UI Widget  
  └─ lib/features/orders/widgets/cancel_order_dialog.dart

✓ Integration
  └─ lib/features/orders/screens/order_detail_screen.dart

✓ Database
  ├─ firestore.rules (permission)
  └─ OrderModel (cancelledAt, cancellationReason fields)

✓ Existing Service (no changes needed)
  └─ lib/features/orders/services/order_service.dart
     (already has cancelOrder() with atomic batch write)
```

---

## Key Points

| Feature | Details |
|---------|---------|
| **When** | Only when status = "payment_verification_pending" |
| **What** | Updates status + restores stock (atomic) |
| **Who** | Customer can cancel own orders only |
| **How** | Button → Dialog → Confirm → Auto-refresh |
| **Undo** | Admin can use `undoCancelledOrder()` if needed |

---

## Next Steps

1. ✅ Code review of new files
2. ✅ Deploy Firestore rules: `firebase deploy --only firestore:rules`
3. ✅ Test on staging environment
4. ✅ QA approval
5. ✅ Deploy to production

---

See full guide: [ORDER_CANCELLATION_GUIDE.md](ORDER_CANCELLATION_GUIDE.md)
