# Out-of-Stock Item Handling in Active Cart

## Overview
This feature monitors product stock levels in real-time while items are in the customer's shopping cart. When an item goes out of stock, the cart displays a visual indicator and offers the customer a one-click option to remove the unavailable item. This prevents checkout failures and improves the user experience.

## Problem Solved
- **Before**: Customer adds item to cart → Later tries to checkout → "Out of stock" error → Frustration
- **After**: Real-time monitoring → "Out of stock" badge appears immediately → Quick removal option available

## Architecture

### Data Flow
```
Cart Screen Opens
    ↓
CartProvider.initializeStockMonitoring()
    ↓
OutOfStockHandler.initializeStockMonitoring()
    ↓
For each product in cart:
  - Set up Firestore listener on products/{id}.stock
  - Track initial stock
    ↓
Real-time Stock Update (Firestore)
    ↓
Stock becomes 0
    ↓
OutOfStockHandler notifies CartProvider
    ↓
CartProvider updates _outOfStockItems set
    ↓
UI rebuilds via Consumer<CartProvider>
    ↓
CartItemTile shows "Out of Stock" badge
```

## Implementation Details

### 1. OutOfStockHandler Service
**File**: `lib/features/cart/services/out_of_stock_handler.dart`

**Responsibility**: Manages real-time Firestore listeners for product stock

**Key Methods**:
- `initializeStockMonitoring(productIds, onStockChanged)` - Set up listeners
- `getStock(productId)` - Get current stock level
- `isOutOfStock(productId)` - Check if out of stock (stock == 0)
- `isLowStock(productId, threshold)` - Check if stock below threshold (default: 5)
- `removeListener(productId)` - Stop listening to a product
- `dispose()` - Clean up all listeners

**How It Works**:
1. For each product ID in cart, creates a real-time Firestore listener
2. Listens to `products/{productId}` document, specifically the `stock` field
3. On stock change, calls the callback function passed to `initializeStockMonitoring`
4. Stores current stock in `_currentStock` map for quick access
5. Only notifies listeners if stock actually changed

### 2. CartProvider Integration
**File**: `lib/features/cart/providers/cart_provider.dart`

**New Properties**:
```dart
final OutOfStockHandler _outOfStockHandler = OutOfStockHandler();
final Set<String> _outOfStockItems = {};        // Products with stock == 0
final Set<String> _lowStockItems = {};          // Products with stock <= 5
```

**New Methods**:
- `initializeStockMonitoring()` - Start monitoring all cart items
- `isItemOutOfStock(productId)` - Check if item is out of stock
- `isItemLowStock(productId)` - Check if item is low stock
- `removeOutOfStockItem(productId)` - Remove item and cleanup listener
- `_handleStockChange(productId, newStock)` - Internal handler for stock changes
- `dispose()` - Cleanup all listeners (override from ChangeNotifier)

**Stock Status Flow**:
1. When stock becomes 0 → Add to `_outOfStockItems`
2. When stock becomes available again → Remove from `_outOfStockItems`
3. When stock is low (≤5) → Add to `_lowStockItems`
4. When stock is sufficient again → Remove from `_lowStockItems`

### 3. CartItemTile UI Updates
**File**: `lib/features/cart/widgets/cart_item_tile.dart`

**New Parameters**:
```dart
final bool isOutOfStock;     // Passed from CartScreen
final bool isLowStock;       // Passed from CartScreen
```

**Visual Indicators**:

**Out of Stock**:
- Product image: 30% black overlay
- Product name: Strikethrough, grayed out
- Red badge: "Out of Stock"
- Quantity controls: Hidden, replaced with red delete button
- Delete button: Shows confirmation dialog before removing

**Low Stock** (5 units or less):
- Amber badge: "Low Stock"
- Quantity controls: Still enabled
- User can continue using product

### 4. CartScreen Integration
**File**: `lib/features/cart/screens/cart_screen.dart`

**Lifecycle**:
```dart
class CartScreen extends StatefulWidget { }

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    // Initialize stock monitoring when screen opens
    Future.delayed(Duration.zero, _initializeStockMonitoring);
  }

  @override
  void dispose() {
    // Cleanup listeners when screen closes
    cartProvider.dispose();
    super.dispose();
  }
}
```

**Consumer Usage**:
```dart
// Pass out-of-stock status to CartItemTile
final isOutOfStock = cartProvider.isItemOutOfStock(item.productId);
final isLowStock = cartProvider.isItemLowStock(item.productId);

CartItemTile(
  item: item,
  cartProvider: cartProvider,
  isOutOfStock: isOutOfStock,
  isLowStock: isLowStock,
)
```

## Firestore Listener Details

**Watched Path**: `projects/{projectId}/databases/(default)/documents/products/{productId}`

**Field Watched**: `stock` (number)

**Listener Lifecycle**:
1. Created when product is in cart
2. Runs continuously while cart screen is open
3. Cancelled when:
   - Item is removed from cart
   - Cart screen is closed (disposed)
   - App is closed

**Database Rules**:
```firestore
// In firestore.rules
match /products/{productId} {
  // Cloud Functions and customers can read products (including stock)
  allow read: if isAuthenticated() || isCloudFunction();
}
```

## Stock Change Scenarios

### Scenario 1: Item Goes Out of Stock
```
Initial: Product has 5 units
User's Cart: Product quantity = 2
Firestore Update: Product stock → 0
↓
OutOfStockHandler detects change
↓
Calls cartProvider._handleStockChange('productId', 0)
↓
CartProvider adds product ID to _outOfStockItems
↓
notifyListeners()
↓
UI rebuilds
↓
CartItemTile shows "Out of Stock" badge
```

### Scenario 2: Item Back in Stock
```
Initial: Product stock = 0 (out of stock)
Firestore Update: Product stock → 10
↓
OutOfStockHandler detects change
↓
Calls cartProvider._handleStockChange('productId', 10)
↓
CartProvider removes product ID from _outOfStockItems
↓
notifyListeners()
↓
UI rebuilds
↓
CartItemTile shows normal quantity controls again
```

### Scenario 3: Low Stock Warning
```
Initial: Product stock = 10
Firestore Update: Product stock → 3
↓
OutOfStockHandler detects change
↓
Calls cartProvider._handleStockChange('productId', 3)
↓
CartProvider adds product ID to _lowStockItems
↓
notifyListeners()
↓
UI rebuilds
↓
CartItemTile shows "Low Stock" badge (amber)
```

## User Interactions

### Out-of-Stock Item
**User sees**: 
- Product image with dark overlay
- Red "Out of Stock" badge
- Delete button (red icon)

**When user taps delete button**:
1. Confirmation dialog appears: "Remove from cart?"
2. If confirmed: `cartProvider.removeOutOfStockItem(productId)`
   - Removes item from cart
   - Cancels Firestore listener
   - Removes from tracking sets
3. SnackBar confirms: "Product removed from cart"

### Low Stock Item
**User sees**:
- Amber "Low Stock" badge
- Quantity controls still enabled
- User can still add/remove units

**User can**:
- Continue shopping with the item at current quantity
- Increase quantity (if stock allows)
- Decrease quantity
- Manually remove if they choose to

## Testing Checklist

### Unit Tests
- [ ] OutOfStockHandler correctly tracks stock changes
- [ ] CartProvider correctly updates _outOfStockItems set
- [ ] CartProvider.isItemOutOfStock() returns correct status

### Integration Tests
- [ ] CartScreen initializes stock monitoring on open
- [ ] Stock updates appear in real-time (< 1 second)
- [ ] CartItemTile displays badges correctly
- [ ] Removing out-of-stock item works as expected

### Manual Testing
1. **Setup**:
   - Add product to cart
   - Open cart screen
   - Leave cart screen open

2. **Test Out-of-Stock**:
   - In Firestore console, set product stock to 0
   - Observe: "Out of Stock" badge appears within 1 second
   - Tap delete button
   - Confirm removal dialog
   - Item should disappear from cart

3. **Test Low Stock**:
   - Set product stock to 3
   - Observe: "Low Stock" badge appears
   - Quantity controls still work

4. **Test Back in Stock**:
   - Set product stock back to 10
   - Observe: Badge disappears, quantity controls reappear

5. **Test Multiple Products**:
   - Add 3 different products to cart
   - Open cart
   - Change stock for one product
   - Verify only that product shows the badge

## Performance Considerations

### Firestore Usage
- **Listeners Created**: One per cart item (up to ~20 products typical)
- **Update Frequency**: Only when stock actually changes
- **Cost**: Minimal - reading stock field is cheap operation

### Optimization Tips
1. **Batch Listeners**: Already done - one listener per product
2. **Unsubscribe on Dispose**: Cleanup happens in CartScreen.dispose()
3. **Debounce UI Updates**: Only rebuild if stock value actually changed
4. **Memory Management**: Stock listeners cleared when items removed from cart

### Scalability
- Can handle 50+ products in cart (though not realistic)
- Listeners are lazy - only created for products in cart
- No impact on products not in cart

## Error Handling

### Missing Product Document
If product is deleted before cart item removed:
- Listener receives no data
- Log warning: "Product document not found"
- Continue monitoring for future updates

### Network Latency
If stock update takes 5+ seconds:
- Listener still receives update correctly
- User might see delayed badge appearance
- Better than no update at all

### Listener Failure
If Firestore listener fails:
- Error logged to console
- Listener continues to retry automatically
- UI gracefully degrades (shows no badge, allows checkout)

## Limitations & Future Improvements

### Current Limitations
1. Only one Firestore listener per product (not by user)
2. No sound/vibration notification for out-of-stock
3. No email notification to customer
4. No automatic cart adjustment (doesn't remove OOS items on checkout)

### Future Enhancements
1. **Batch Remove**: "Remove all out-of-stock items" button
2. **Notifications**: Push notification when item goes OOS
3. **Auto-Adjust Quantity**: Reduce quantity to available stock
4. **Wishlist**: Add out-of-stock items to wishlist instead of removing
5. **Restock Alert**: Notify when out-of-stock item returns
6. **Analytics**: Track which products go OOS most frequently

## Security Notes

✅ **What's Protected**:
- Stock field is readable (it's public product data)
- Can't modify stock through app (only via admin dashboard or backend)
- Each user only monitors their own cart

✅ **What's Verified**:
- Firestore rules allow reads of `products/{id}/stock`
- No user can modify stock directly
- Stock updates come from backend (admin actions, orders)

## Phase & Status
- **Phase**: Phase 2 (Post-MVP)
- **Status**: ✅ Complete
- **Priority**: 🟠 IMPORTANT
- **Solves**: Cryptic checkout failures → Proactive stock management
