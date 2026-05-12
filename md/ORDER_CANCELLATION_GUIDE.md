# Order Cancellation by Customer - Implementation Guide

## Overview

Customers can now cancel orders **before the vendor starts preparation**. This provides essential control over their purchases and improves the user experience by preventing wasted preparation time.

**Status**: ✅ MVP / Phase 1 Feature - Fully Implemented

---

## Feature Requirements

### When Can Orders Be Cancelled?

Orders can **only** be cancelled when their status is **`payment_verification_pending`** — this means:
- ✅ Payment has been received
- ✅ Upload proof is complete
- ❌ Vendor has **NOT** started verification/preparation yet

### What Happens on Cancellation?

1. **Order Status**: Updated to `cancelled`
2. **Stock Restoration**: All items are added back to inventory
3. **Timestamp**: `cancelledAt` field is recorded
4. **Atomic Operation**: Stock and status changes happen together (no inconsistencies)

### User Experience Flow

1. Customer views order details
2. **Cancel Order button appears** (red button, visible only if status == `payment_verification_pending`)
3. Customer taps "Cancel Order"
4. **Confirmation dialog** appears with:
   - Order summary (ID, items, total)
   - Warning: "This action cannot be undone"
   - "Cancel Order" / "Keep Order" buttons
5. On confirm:
   - ✅ Shows success message
   - ✅ Auto-refreshes order details (status changes to "cancelled")
   - ✅ Auto-navigates back to order history

---

## Architecture

### Core Components

#### 1. **OrderCancellationService** (Order Cancellation Logic)
**File**: `lib/features/orders/services/order_cancellation_service.dart`

```dart
class OrderCancellationService {
  /// Check if order can be cancelled (status must be 'paymentVerificationPending')
  bool canCancelOrder(OrderModel order)
  
  /// Cancel order with validation and stock restoration
  Future<void> cancelOrder(String orderId, {String? reason})
  
  /// List all orders eligible for cancellation
  Stream<List<OrderModel>> getOrdersEligibleForCancellation(String customerId)
  
  /// Admin function: Undo cancellation and restore order
  Future<void> undoCancelledOrder(String orderId)
}
```

**Key Features**:
- ✅ Validates order status before cancellation
- ✅ Prevents cancelling orders already in preparation
- ✅ Restores stock atomically with status change
- ✅ Records cancellation timestamp and reason
- ✅ Admin recovery function for support cases

#### 2. **CancelOrderDialog** (Confirmation UI)
**File**: `lib/features/orders/widgets/cancel_order_dialog.dart`

User-facing confirmation dialog with:
- ⚠️ Warning icon and message
- 📋 Order summary (ID, items, total)
- ❌ Clear warning: "This action cannot be undone"
- 🔴 Red "Cancel Order" button
- 🔵 Blue "Keep Order" button
- ⏳ Loading state during cancellation
- ❌ Error handling with retry option

#### 3. **OrderDetailScreen** (Integration)
**File**: `lib/features/orders/screens/order_detail_screen.dart`

Enhanced with:
- **Conditional Cancel Button**: Visible only when `order.status == OrderStatus.paymentVerificationPending`
- **Dialog Integration**: Shows `CancelOrderDialog` on tap
- **Result Handling**: Success message + auto-navigation
- **Real-time Updates**: StreamBuilder auto-refreshes order status

#### 4. **OrderModel** (Enhanced Data Model)
**File**: `lib/features/orders/models/order_model.dart`

Added cancellation fields:
```dart
final String? cancellationReason;      // Why customer cancelled
final DateTime? cancelledAt;            // When cancelled
```

#### 5. **OrderService** (Atomic Operations)
**File**: `lib/features/orders/services/order_service.dart`

Existing `cancelOrder()` method provides:
```dart
Future<void> cancelOrder(String orderId)
  // 1. Updates order.status = 'cancelled'
  // 2. Records cancelledAt timestamp
  // 3. Increments stock for all items (atomic batch write)
  // 4. Returns only when all operations complete
```

**Atomic Batch Write** ensures:
- Stock changes and status changes happen together
- No orphaned stock if status update fails
- No duplicate stock restoration

---

## Implementation Checklist

### ✅ Completed

- [x] OrderModel updated with `cancellationReason` and `cancelledAt` fields
- [x] OrderCancellationService created with validation logic
- [x] CancelOrderDialog widget created with confirmation UI
- [x] OrderDetailScreen enhanced with cancel button
- [x] Firestore rules updated to allow customer cancellation
- [x] OrderService has working `cancelOrder()` method

### Database Schema Changes

#### Orders Collection
```
orders/{orderId}
├── customerId: string
├── status: string                  // Changed to "cancelled"
├── paymentVerificationPending: ... // Original status
├── cancellationReason: string      // NEW FIELD (optional)
├── cancelledAt: timestamp          // NEW FIELD (when cancelled)
└── ... (other fields)
```

#### Products Collection
Stock changes via `FieldValue.increment()` (automatic in batch write)

---

## Firestore Rules

### Order Cancellation Permission

```firestore
// Users can cancel their own orders when pending payment verification
allow update: if resource.data.customerId == request.auth.token.phone_number &&
                 resource.data.status == 'paymentVerificationPending' &&
                 request.resource.data.status == 'cancelled';
```

**Security**:
- ✅ Only order owner can cancel
- ✅ Only cancellable from `paymentVerificationPending` status
- ✅ Only to `cancelled` status (prevents state confusion)
- ✅ Admin override always available

---

## Usage Examples

### Basic Cancellation Flow

**1. Check if order can be cancelled**
```dart
final service = OrderCancellationService();
bool canCancel = service.canCancelOrder(order);

if (canCancel) {
  // Show cancel button
}
```

**2. Cancel order with confirmation**
```dart
try {
  await OrderCancellationService().cancelOrder(orderId);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Order cancelled successfully'))
  );
  Navigator.pop(context); // Go back to history
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: ${e.toString()}'))
  );
}
```

**3. List cancellable orders**
```dart
final service = OrderCancellationService();
final cancellableOrders = service.getOrdersEligibleForCancellation(customerId);

cancellableOrders.listen((orders) {
  // Update UI with cancellable orders count
});
```

### Admin Recovery (Support Case)

```dart
// If customer wants to restore cancelled order
await OrderCancellationService().undoCancelledOrder(orderId);
// Status restored to 'paymentVerificationPending'
// Stock restored to original amounts
```

---

## State Transitions

```
BEFORE CANCELLATION:
Order Status: paymentVerificationPending
Stock: Reduced (item already deducted)
Reason: Waiting for vendor verification

AFTER CANCELLATION:
Order Status: cancelled
Stock: Restored (added back to inventory)
Timestamp: cancelledAt recorded
Payment: Refund required (manual via admin)

CUSTOMER PERSPECTIVE:
1. Order Details page → Cancel button visible
2. Tap Cancel → Confirmation dialog
3. Confirm → Success message
4. Auto-refresh → Status shows "cancelled"
5. Auto-navigate → Return to order history
```

---

## Error Handling

### Validation Errors

**❌ Cannot cancel if**:
- Order status ≠ `paymentVerificationPending`
- Order already started preparation
- Order already completed
- Order already cancelled

**Response**: Dialog shows error, allows retry

### Network Errors

**On cancellation request failure**:
- Error message displayed in dialog
- "Try Again" button enabled
- Original order state preserved

### Concurrency Issues

**Atomic batch writes prevent**:
- Stock restoration without status change
- Status change without stock restoration
- Race conditions between multiple cancels

---

## Testing

### Unit Tests (OrderCancellationService)

```dart
test('canCancelOrder returns true for paymentVerificationPending', () {
  final order = OrderModel(
    status: OrderStatus.paymentVerificationPending,
    // ... other fields
  );
  
  final service = OrderCancellationService();
  expect(service.canCancelOrder(order), true);
});

test('cancelOrder updates status to cancelled', () async {
  // Create test order
  // Call cancelOrder()
  // Verify Firestore status field = 'cancelled'
  // Verify stock incremented for all items
});
```

### Integration Tests (UI Flow)

```dart
testWidgets('Cancel button visible only when paymentVerificationPending', 
  (WidgetTester tester) async {
    // Create order with status = paymentVerificationPending
    // Build OrderDetailScreen
    // Verify cancel button is visible
    
    // Change status to pendingPayment
    // Verify cancel button is hidden
  }
);

testWidgets('Tapping cancel shows confirmation dialog', 
  (WidgetTester tester) async {
    // Build OrderDetailScreen
    // Tap cancel button
    // Verify CancelOrderDialog appears with order details
  }
);
```

### Manual Testing Checklist

- [ ] Order detail page loads with cancel button (when status = paymentVerificationPending)
- [ ] Cancel button hidden for other statuses
- [ ] Tapping cancel shows dialog with order summary
- [ ] Tapping "Keep Order" closes dialog without changes
- [ ] Tapping "Cancel Order" shows loading spinner
- [ ] After cancellation: success message + auto-back navigation
- [ ] Order history now shows cancelled order (filtered correctly)
- [ ] Firebase console: order.status = "cancelled", stock incremented
- [ ] Firebase console: order.cancelledAt timestamp set
- [ ] Admin can view cancelled orders and undo if needed

---

## Future Enhancements

1. **Automated Refunds**: Trigger refund process on cancellation
2. **Cancellation Reason Tracking**: Analytics on why customers cancel
3. **Smart Timeouts**: Auto-cancel orders if vendor doesn't verify within X hours
4. **Partial Refunds**: Support for partial order cancellation (some items only)
5. **Cancellation Policy**: Display cancellation terms to customer
6. **Notification**: Send WhatsApp notification when customer cancels

---

## Files Modified

| File | Changes | Type |
|------|---------|------|
| `order_model.dart` | Added `cancellationReason`, `cancelledAt` | Model |
| `order_detail_screen.dart` | Added cancel button + dialog integration | UI |
| `order_cancellation_service.dart` | New service file | Service |
| `cancel_order_dialog.dart` | New dialog widget | Widget |
| `firestore.rules` | Added cancellation permission | Rules |

---

## FAQ

**Q: Can customers cancel after vendor starts preparation?**
A: No. Once vendor starts verification, status changes to `payment_verified` and cancel button disappears.

**Q: What about refunds?**
A: Stock is restored automatically. Refund payment handling is separate (manual via admin for now).

**Q: Can cancelled orders be restored?**
A: Only by admin using `undoCancelledOrder()` function. Customer cannot re-activate.

**Q: What if network fails during cancellation?**
A: Dialog shows error, customer can retry. Stock not affected until confirmation.

**Q: Are cancellation records permanent?**
A: Yes. `cancelledAt` timestamp is recorded. Useful for analytics and support.

---

## Support & Debugging

### Common Issues

**Cancel button not showing**
- Check: `order.status == OrderStatus.paymentVerificationPending`
- Check: StreamBuilder is watching correct order ID
- Check: OrderModel.fromFirestore() is parsing status correctly

**Cancellation fails with permission error**
- Check: Firestore rules include cancellation update rule
- Check: User is authenticated (phone_number in token)
- Check: Order owner matches request.auth.token.phone_number

**Stock not restored**
- Check: `cancelOrder()` in OrderService uses batch write
- Check: Product references in batch match actual product IDs
- Check: No Firestore transaction conflicts

---

## Related Documentation

- [Payment Failure & Retry Flow Guide](PAYMENT_FAILURE_RETRY_GUIDE.md)
- [Order Creation Guide](ORDER_CREATION_GUIDE.md)
- [Firebase Setup Guide](FIREBASE_SETUP.md)
- [Implementation Checklist](IMPLEMENTATION_CHECKLIST.md)

---

**Last Updated**: Phase 1 MVP
**Status**: ✅ Complete & Ready for Testing
**Feature Owner**: Order Management Team
