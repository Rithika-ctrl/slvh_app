# Stock Reservation on Order Placement

## Overview
Stock is reserved **atomically** when an order is created using Firestore Transactions. This prevents overselling when multiple customers order the last item simultaneously.

## Problem Solved
Two customers order the last item at the exact same time:
- Without atomic transactions: Both orders succeed → stock goes negative (-1) → fulfillment failure
- With atomic transactions: Transaction 1 reserves stock ✅ → Transaction 2 gets "out of stock" ❌

## Architecture

### Firestore Transactions vs Batch Writes
| Feature | Batch Write | Firestore Transaction |
|---------|-------------|----------------------|
| Atomicity | Writes only | Reads + conditional writes |
| Use Case | No validation needed | Validate before updating |
| Stock Reservation | ❌ Can't check before decrementing | ✅ Check then decrement atomically |
| Order Cancellation | ✅ Just restore | ✅ Works but overkill |

**Stock Reservation uses Transactions** because we must:
1. Read current stock
2. Validate stock >= requested quantity
3. Decrement stock only if valid
4. Fail entire transaction if not valid (rollback)

## Implementation

### StockService (lib/features/inventory/services/stock_service.dart)

#### reserveStock(items) - CRITICAL OPERATION
```dart
Future<Map<String, int>> reserveStock(List<OrderItem> items)
```

**Firestore Transaction Flow:**
```
START TRANSACTION
├─ STEP 1: Read all product documents (products/{id})
├─ STEP 2: Validate stock >= quantity for each item
│   └─ If any invalid → THROW StockReservationException → ROLLBACK
├─ STEP 3: Atomically update all stock fields
│   └─ stock = currentStock - requestedQuantity
└─ COMMIT all updates together (all-or-nothing)
```

**Safety Guarantees:**
- No race conditions: Firestore serializes transactions
- Atomic: All products decrement together or not at all
- Validated: Stock checked before any updates
- Isolated: Concurrent orders don't interfere

**Example - Two Simultaneous Orders:**
```
Stock: Item A = 1

Customer 1 orders 1 unit → Transaction 1
├─ Read: stock = 1
├─ Validate: 1 >= 1 ✅
└─ Decrement: stock = 0 ✅ COMMITS

Customer 2 orders 1 unit → Transaction 2 (starts while 1 is committing)
├─ Read: stock = 1 (read before 1 committed)
├─ Validate: 1 >= 1 ✅
└─ Conflict: Firestore detects concurrent modification → RETRY
  └─ Re-read: stock = 0 (reads after 1 committed)
  └─ Validate: 0 >= 1 ❌ FAILS → StockReservationException
```

#### validateStock(items) - Pre-Order Validation
```dart
Future<StockReservationException?> validateStock(List<OrderItem> items)
```
- Checks stock without reserving
- Useful for instant UI feedback before checkout
- Not atomic (informational only)
- Returns null if all valid, or exception if not

#### releaseStock(productId, quantity) - Order Cancellation
```dart
Future<int> releaseStock(String productId, int quantity)
```
- Adds quantity back to product stock
- Used when orders are cancelled
- Also uses transaction for safety
- Returns new stock level after release

### StockReservationException
```dart
class StockReservationException {
  final String message;
  final String? productId;
  final String? productName;
  final int? requiredQuantity;
  final int? availableQuantity;
}
```

Detailed exception with:
- Human-readable message for UI
- Product context for logging
- Quantities for analytics

### OrderService Integration
```dart
// OLD: Batch write (no validation)
final batch = _firestore.batch();
batch.set(order);
batch.update(product, {'stock': FieldValue.increment(-qty)});
await batch.commit(); // ❌ Can go negative!

// NEW: Atomic transaction (validates before updating)
final newStockLevels = await _stockService.reserveStock(order.items);
await _firestore.collection('orders').doc(orderId).set(order);
// ✅ Stock only decremented if validation passed
```

## Firestore Rules

Already in firestore.rules:
```
// Products collection - stock is publicly readable, admin updatable
match /products/{productId} {
  allow read: if isPublic();
  allow update: if isAdmin() || isCloudFunction();
}

// Orders collection - users can create own, admin can update
match /orders/{orderId} {
  allow create: if isPhoneOwner(resource.data.phoneNumber);
  allow read: if isPhoneOwner(resource.data.phoneNumber) || isAdmin();
  allow update: if isAdmin() || isCloudFunction();
}
```

Key permissions:
- ✅ Users can create orders (order placement)
- ✅ Admin can update products (stock management)
- ✅ Cloud Functions can manage both (automated tasks)

## User Experience Flow

### Successful Order
```
1. Customer adds items to cart
2. Customer clicks "Place Order"
3. App calls OrderService.createOrder()
   ├─ StockService.reserveStock() runs Firestore Transaction
   │ ├─ ✅ All products have sufficient stock
   │ └─ Stock decremented atomically
   └─ Order document created
4. ✅ "Order confirmed" screen
5. Stock updated in real-time
```

### Out of Stock
```
1. Customer adds 2 units (only 1 available)
2. Customer clicks "Place Order"
3. App calls OrderService.createOrder()
   ├─ StockService.reserveStock() runs Firestore Transaction
   │ ├─ ❌ Insufficient stock for Item A (required 2, available 1)
   │ └─ Transaction ROLLS BACK (stock unchanged)
   └─ StockReservationException thrown
4. ❌ "Out of stock" error shown
5. Stock never changed
```

### Concurrent Orders (Race Condition Test)
```
Time T0: Stock for Item A = 1

T1: Customer 1 places order for 1 unit (Transaction A starts)
T1: Customer 2 places order for 1 unit (Transaction B starts)

T2: Transaction A commits → Stock = 0
T2: Transaction B retries (detects conflict)
    → Re-reads stock = 0
    → Validates: 0 >= 1? NO
    → Throws StockReservationException
    → Customer 2 gets error message

Result: Item A never oversold ✅
```

## Testing Checklist

### Unit Tests
- [ ] `reserveStock()` with sufficient stock → succeeds
- [ ] `reserveStock()` with insufficient stock → throws exception
- [ ] `reserveStock()` with empty items → returns empty map
- [ ] `validateStock()` pre-checks without reserving
- [ ] `releaseStock()` adds back to stock
- [ ] Exception contains correct product/quantity info

### Integration Tests
- [ ] Place order → stock decrements in Firestore
- [ ] Try oversell (stock=1, order qty=2) → fails
- [ ] Cancel order → stock restored
- [ ] Multiple rapid orders → no negative stock

### Stress Tests (Concurrent)
- [ ] Simulate 5 customers ordering last item simultaneously
  - Expectations: 1 succeeds, 4 get out-of-stock errors
  - Verify: Final stock = 0 (never negative)

### UI Tests
- [ ] Show "Out of Stock" message on StockReservationException
- [ ] Display product name and required/available quantities in error
- [ ] Disable "Place Order" button if validateStock() fails
- [ ] Show loading spinner during reservation

## Error Handling

### In App
```dart
try {
  final orderId = await orderService.createOrder(order);
  // Show success screen
} on StockReservationException catch (e) {
  // Show error with product name
  showDialog(
    title: 'Out of Stock',
    message: e.message,
    subtitle: 'Available: ${e.availableQuantity}, Required: ${e.requiredQuantity}',
  );
} catch (e) {
  // Show generic error
  showErrorSnackbar('Failed to place order');
}
```

### Logging
All operations log to console:
- ✅ `"Stock reserved atomically for 3 items"`
- ✅ `"Stock released: +2 for product ABC123"`
- ❌ `"Stock reservation failed: Insufficient stock for Item X"`

## Riverpod Integration

```dart
// Reserve stock provider
final reserveStockProvider = FutureProvider.family<Map<String, int>, List<OrderItem>>(
  (ref, items) => ref.read(stockServiceProvider).reserveStock(items),
);

// Validate stock (for UI feedback)
final validateStockProvider = FutureProvider.family<StockReservationException?, List<OrderItem>>(
  (ref, items) => ref.read(stockServiceProvider).validateStock(items),
);

// Get current stock (for product pages)
final productStockProvider = FutureProvider.family<int, String>(
  (ref, productId) => ref.read(stockServiceProvider).getProductStock(productId),
);

// Usage in widgets
@override
Widget build(BuildContext context, WidgetRef ref) {
  final stockAsync = ref.watch(productStockProvider(productId));
  
  return stockAsync.when(
    data: (stock) => Text('Stock: $stock'),
    loading: () => CircularProgressIndicator(),
    error: (err, _) => Text('Error: ${err.message}'),
  );
}
```

## Monitoring & Analytics

### Log Output Examples
**Success:**
```
📦 Creating order with 2 items...
✅ Stock reserved atomically for 2 items: {prod_1: 9, prod_2: 5}
✅ Order created: order_12345
```

**Failure:**
```
📦 Creating order with 2 items...
❌ Stock reservation failed: Insufficient stock for Milk Shake. Required: 10, Available: 2
```

### Metrics to Track
- Order creation success rate
- Out-of-stock rejection rate
- Average transaction latency
- Peak concurrent orders

## Current Status
✅ StockService created with atomic transaction logic
✅ OrderService updated to use StockService.reserveStock()
✅ StockReservationException with detailed error info
✅ Riverpod providers for stock management
✅ Firestore rules already support operations
⏳ UI integration (error dialogs, validation feedback) - TODO
⏳ Testing suite - TODO
