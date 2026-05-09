# Inventory Management System - User Guide

## Overview
Phase 3 Inventory implementation provides real-time stock tracking with color-coded status indicators, manual stock adjustments with audit trails, and automatic low-stock alerts through Cloud Functions.

---

## 🎯 Key Features

### 1. **Real-time Stock Tracking**
- All products display current stock levels in real-time
- Color-coded status badges:
  - 🟢 **Green**: In Stock (stock > threshold)
  - 🟡 **Amber**: Low Stock (stock ≤ threshold)
  - 🔴 **Red**: Out of Stock (stock = 0)
- Threshold customizable per shop (default: 10 units)

### 2. **Inventory Dashboard (Admin Only)**
- Access: Admin Dashboard → "Manage Inventory" → `/inventory` route
- Tab-based filtering:
  - **All Products**: View all products with current stock
  - **Low Stock**: View only products below threshold
  - **Out of Stock**: View products with zero stock

### 3. **Stock Adjustment**
- Click "Adjust Stock" button on any product card
- Features:
  - Toggle between **Add** or **Remove** operations
  - Enter quantity to adjust
  - Provide reason for audit trail
  - Atomic database transaction (prevents negative stock)
  - Immediate UI update via StreamBuilder

### 4. **Audit Trail**
- Click "History" button to view stock adjustment history
- Shows:
  - Change amount (+ or -)
  - Reason for adjustment
  - Timestamp of change
  - Real-time updates as new adjustments occur

### 5. **Low Stock Alerts**
- Cloud Function monitors all products
- Automatically creates alert when stock:
  - Falls below threshold
  - Reaches zero
- Alert data logged in Firestore `low_stock_alerts` collection
- Expandable to push notifications or admin WhatsApp alerts

### 6. **Threshold Management**
- Click floating action button (⚙️) on Inventory Screen
- Set low-stock threshold globally (default: 10)
- Changes apply instantly to all products
- Affects color-coding on product cards throughout app

---

## 📊 Firestore Schema

### Collections

#### `products/{productId}`
```javascript
{
  id: string,
  name: string,
  price: number,
  stock: number,
  // ... other product fields
}
```
**Note**: `stock` field is decremented when:
- Order is created (batch write)
- Admin manually adjusts inventory

#### `app_settings/inventory`
```javascript
{
  lowStockThreshold: 10  // global threshold
}
```

#### `stock_adjustments/{adjustmentId}`
```javascript
{
  productId: string,
  quantityChange: number,    // positive or negative
  reason: string,            // e.g., "Received new batch", "Damaged goods"
  adminId: string,           // admin who made adjustment
  timestamp: Timestamp
}
```

#### `low_stock_alerts/{alertId}` (Auto-created)
```javascript
{
  productId: string,
  productName: string,
  currentStock: number,
  threshold: number,
  isOutOfStock: boolean,
  previousStock: number,
  alertSentAt: Timestamp,
  alertLevel: "low_stock" | "out_of_stock"
}
```

---

## 🛠️ Code Architecture

### Service Layer
**File**: `lib/features/inventory/services/inventory_service.dart`

Key methods:
- `watchAllProductsWithStock()` - Real-time stream of all products
- `adjustStock(productId, quantityChange, reason, adminId)` - Make adjustment
- `getStockAdjustmentHistory(productId)` - Fetch audit trail
- `getLowStockThreshold()` / `setLowStockThreshold(threshold)` - Manage threshold
- `watchLowStockProducts()` - Stream of low stock items
- `getInventoryStats()` - Overall inventory summary

### UI Widgets
**File**: `lib/features/inventory/widgets/stock_indicator.dart`

Components:
- `StockIndicator` - Main status widget with color and label
- `StockBadge` - Compact circular badge with stock count
- `StockRow` - List item row with stock info
- `LowStockWarning` - Warning card for cards
- `StockInfoCard` - Detailed card with full stock info

### Admin Screen
**File**: `lib/features/inventory/screens/inventory_screen.dart`

Features:
- Tab-based product filtering
- Real-time StreamBuilder updates
- Stock adjustment dialog with validation
- History viewer
- Threshold settings

### Routing
**File**: `lib/routes/app_router.dart`

- Route constant: `AppRoutes.inventory = '/inventory'`
- Admin-only route guard
- Accessible from: Admin Dashboard → "Manage Inventory"

---

## 🔧 Integration Points

### Stock Auto-Decrement on Order Creation
**File**: `lib/features/orders/services/order_service.dart`

When order is created:
```dart
// Batch write reduces product stock atomically
batch.update(productRef, {'stock': FieldValue.increment(-quantity)});
```

### Product Card Enhancement
**File**: `lib/features/products/widgets/product_card.dart`

Stock badge now:
- Uses InventoryService to get low stock threshold
- Shows "In Stock", "Low Stock", or "Out of Stock"
- Color-codes based on stock level

---

## ☁️ Cloud Functions

### Trigger: onProductStockLow
**File**: `functions/src/index.ts`

Fires when:
- Any product's `stock` field is updated
- Compares new stock to threshold from `app_settings/inventory`

Behavior:
- Creates entry in `low_stock_alerts` collection
- Logs alert event with details
- TODO: Can be extended to send admin notifications

Deploy:
```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

---

## 📱 User Workflows

### Workflow 1: Check Inventory Status
1. Login as admin
2. Go to Admin Dashboard
3. Click "Manage Inventory"
4. View all products with real-time stock levels
5. Switch tabs to see Low Stock or Out of Stock items

### Workflow 2: Adjust Stock Manually
1. Navigate to Inventory Screen
2. Find product card
3. Click "Adjust Stock" button
4. Choose Add or Remove operation
5. Enter quantity (e.g., 5 units)
6. Enter reason (e.g., "Received delivery from supplier")
7. Click "Update"
8. Verify change appears immediately
9. Click "History" to see adjustment in audit trail

### Workflow 3: Set Low Stock Threshold
1. On Inventory Screen, click floating action button (⚙️)
2. Enter new threshold value (e.g., 15 units)
3. Click "Save"
4. All products instantly update their color-coding
5. ProductCards throughout app reflect new threshold

### Workflow 4: Monitor Low Stock Alerts
1. Set threshold to reasonable value (e.g., 10 units)
2. As stock is used/sold, products reach threshold
3. Low stock alert automatically created in Firestore
4. Admins see products in "Low Stock" tab
5. Reason for restocking becomes clear

---

## 🔒 Security

### Firestore Rules
```javascript
// Only admins can read/write inventory data
match /products/{productId} {
  allow write: if isAdmin();
  allow read: if isAdmin() || request.auth.uid != null;
}

match /stock_adjustments/{adjustmentId} {
  allow write: if isAdmin();
  allow read: if isAdmin();
}

match /app_settings/{document=**} {
  allow write: if isAdmin();
  allow read: if request.auth.uid != null;
}
```

### Access Control
- Inventory Screen: Admin-only route (guarded in `app_router.dart`)
- Stock adjustment: Requires admin login
- Settings change: Admin-only

---

## 📊 Inventory Stats

**Available** via `InventoryService.watchInventoryStats()`:
- `totalProducts` - Number of unique products
- `totalStock` - Sum of all stock quantities
- `okStock` - Products above threshold
- `lowStock` - Products at/below threshold
- `outOfStock` - Products with zero stock
- `lowStockThreshold` - Current threshold setting

Use in custom dashboards or analytics.

---

## 🐛 Troubleshooting

### Stock not updating in real-time
- Check Firestore rules allow write access
- Verify admin authentication
- Check network connection
- Restart app if stuck

### Color-coding incorrect
- Verify threshold value via settings
- Check that product.stock field exists in Firestore
- Ensure stock value is numeric (not string)

### Adjustment history empty
- New adjustments should appear within 2-3 seconds
- Verify stock_adjustments collection is created
- Check browser console for errors

### Low stock alerts not created
- Verify app_settings/inventory exists with lowStockThreshold
- Check Cloud Functions deployed with `firebase deploy --only functions`
- View function logs: `firebase functions:log`

---

## 🚀 Future Enhancements

Potential features to build on this foundation:

1. **Push Notifications**
   - Send admin FCM notification when stock falls below threshold
   - Send WhatsApp alert for critical items (stock = 0)

2. **Bulk Import**
   - CSV upload to bulk update stock levels
   - Batch import with transaction support

3. **Predictive Analytics**
   - Forecast low stock dates based on sales velocity
   - Suggest reorder quantities

4. **Multi-Warehouse**
   - Track stock across multiple warehouses
   - Automatic allocation to fulfillment

5. **Supplier Integration**
   - Auto-send reorder request when stock hits threshold
   - Track supplier lead times

6. **Stock Movement Reports**
   - Visualize stock trends over time
   - Identify fast-moving vs. slow-moving items

---

## 📞 Support

For issues or questions:
1. Check Firestore console for data structure
2. Review Cloud Functions logs: `firebase functions:log`
3. Check Flutter console for widget errors
4. Verify admin authentication status

---

**Last Updated**: Phase 3 Inventory Implementation Complete
**Version**: 1.0
**Status**: ✅ Production Ready
