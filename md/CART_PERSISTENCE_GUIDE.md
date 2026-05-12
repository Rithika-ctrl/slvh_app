# Cart Persistence Across Sessions

## Overview
Cart is saved to Firestore (`users/{uid}/cart/data`) on every change and loaded on app startup after authentication. Local storage (SharedPreferences) acts as fallback.

## Architecture

### Dual Persistence Strategy
1. **Local**: SharedPreferences for instant access and offline support
2. **Cloud**: Firestore for sync across devices and crash recovery

### Data Structure
```
users/{uid}/cart/data
├── items: [CartItemModel.toJson()]
├── updated_at: timestamp
├── item_count: number
└── total_units: number
```

## Implementation

### Services

#### CartService (lib/features/cart/services/cart_service.dart)
- `saveCart(items)` - Save to Firestore (auto-called on every cart change)
- `loadCart()` - Load from Firestore on app startup
- `watchCart()` - Stream for real-time multi-device sync
- `clearCart()` - Delete from Firestore on logout/checkout
- `getCartSummary()` - Quick metadata fetch

#### CartInitializer (lib/features/cart/services/cart_initializer.dart)
- `loadCartAfterAuth()` - Call after successful login
- `clearOnLogout()` - Call during logout flow

### CartProvider Updates
```dart
// Modified CartProvider._saveCart()
// Now calls both:
// 1. _prefs.setString('cart', json)  // Local
// 2. _cartService.saveCart(_items)    // Cloud

// New method for loading from Firestore
await cartProvider.loadFromFirestore();
```

## Integration Points

### 1. Auth Service (after login)
```dart
// In your auth service after successful authentication:
final cartProvider = ref.read(cartProvider);
await CartInitializer.loadCartAfterAuth(cartProvider);
```

### 2. Logout Flow
```dart
// In logout:
final cartProvider = ref.read(cartProvider);
await CartInitializer.clearOnLogout(cartProvider);
```

### 3. App Startup
```dart
// In main.dart or app initialization:
// Wait for auth to complete, then load cart
if (FirebaseAuth.instance.currentUser != null) {
  // Cart auto-loads via CartProvider._init() → _loadCart()
  // Then explicitly load from Firestore:
  final cartProvider = ref.read(cartProvider);
  await cartProvider.loadFromFirestore();
}
```

## Firestore Rules

Added to firestore.rules:
```rules
// For users organized by phone number
match /users/{phoneNumber}/cart/{document=**} {
  allow read, write: if isPhoneOwner(phoneNumber);
  allow write: if isCloudFunction();
}

// For users organized by UID (standard Firebase)
match /users_by_uid/{uid}/cart/{document=**} {
  allow read, write: if request.auth.uid == uid;
  allow write: if isCloudFunction();
}
```

## User Experience Flow

1. **Add Item** → Save to local + Firestore simultaneously
2. **Quantity Change** → Auto-save to both stores
3. **App Crash** → Restart loads from Firestore (latest saved state)
4. **Login on New Device** → Cart syncs from Firestore
5. **Logout** → Cart cleared from Firestore (local remains for next login)
6. **Offline Mode** → Local cart works, syncs to Firestore when online

## Error Handling

- If Firestore save fails: Local cart still works, fails silently
- If Firestore load fails: Uses local cart as fallback
- If both unavailable: Cart starts empty but repopulates as user adds items

## Testing Scenarios

1. **Persistence**: Add item → Close app → Reopen → Verify item remains
2. **Multi-Device**: Add item on device A → Check Firestore → Load on device B
3. **Offline**: Add item without network → Verify local save → Go online → Verify cloud sync
4. **Logout/Login**: Add item → Logout → Login → Verify cart loads correctly
5. **Crash Recovery**: Add item → Force close → Restart → Verify recovery from Firestore

## Current Status
✅ CartService created with all persistence methods
✅ CartProvider updated to sync with CartService
✅ CartInitializer created for auth lifecycle integration
✅ Firestore rules updated with cart permissions
⏳ Integration points need implementation in auth service & app startup (TODO)
