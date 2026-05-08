# 💰 Dynamic Pricing Module - Multiple Price Tiers

## Overview

The Dynamic Pricing Module enables flexible bulk pricing for products. Customers can see different price tiers based on quantity, encouraging bulk purchases with volume discounts.

**Features:**
- ✅ Multiple price tiers per product
- ✅ Automatic savings percentage calculation
- ✅ Best-value tier highlighting
- ✅ Admin management interface
- ✅ Real-time tier updates
- ✅ Default tier selection

---

## Architecture

### File Structure

```
lib/features/products/
├── models/
│   └── pricing_tier_model.dart              # Price tier data model
├── services/
│   └── pricing_service.dart                 # Firestore operations
└── widgets/
    └── pricing_tiers_widget.dart            # UI components

lib/features/admin/
└── screens/
    └── manage_pricing_screen.dart           # Admin management interface
```

---

## Firestore Collection Structure

### Collection: `products/{productId}/pricing_tiers`

**Document Schema:**

```json
{
  "quantity": 5,
  "unit": "KG",
  "price": 280,
  "isDefault": false,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Fields:**
- `quantity`: Number of units (e.g., 5)
- `unit`: Unit of measurement (e.g., "KG", "L", "ML", "Pack")
- `price`: Total price for this quantity (e.g., ₹280)
- `isDefault`: Whether this is the default tier shown first
- `createdAt`: Creation timestamp
- `updatedAt`: Last update timestamp

---

## Sample Pricing Tiers

### Example 1: Face Wash (Quantity-Based)

Base Product: ₹249

| Quantity | Unit | Price | Per Unit | Savings |
|----------|------|-------|----------|---------|
| 1 | Piece | ₹249 | ₹249 | — |
| 3 | Pieces | ₹699 | ₹233 | 6.4% |
| 6 | Pieces | ₹1,299 | ₹216.50 | **13.1%** ⭐ Best Value |

**Firestore Documents:**

```json
// Tier 1 (Default)
{
  "quantity": 1,
  "unit": "Piece",
  "price": 249,
  "isDefault": true
}

// Tier 2
{
  "quantity": 3,
  "unit": "Pieces",
  "price": 699,
  "isDefault": false
}

// Tier 3 (Best Value)
{
  "quantity": 6,
  "unit": "Pieces",
  "price": 1299,
  "isDefault": false
}
```

---

### Example 2: Cooking Oil (Volume-Based)

Base Product: ₹349 per 1L

| Quantity | Unit | Price | Per Unit | Savings |
|----------|------|-------|----------|---------|
| 1 | L | ₹349 | ₹349 | — |
| 5 | L | ₹1,595 | ₹319 | 8.6% |
| 10 | L | ₹3,090 | ₹309 | **11.5%** ⭐ Best Value |
| 20 | L | ₹5,880 | ₹294 | **15.8%** Corporate |

**Firestore Documents:**

```json
// Tier 1 (Default)
{
  "quantity": 1,
  "unit": "L",
  "price": 349,
  "isDefault": true
}

// Tier 2
{
  "quantity": 5,
  "unit": "L",
  "price": 1595,
  "isDefault": false
}

// Tier 3 (Best Value)
{
  "quantity": 10,
  "unit": "L",
  "price": 3090,
  "isDefault": false
}

// Tier 4
{
  "quantity": 20,
  "unit": "L",
  "price": 5880,
  "isDefault": false
}
```

---

### Example 3: Tissue Paper (Pack-Based)

Base Product: ₹99 per pack

| Quantity | Unit | Price | Per Unit | Savings |
|----------|------|-------|----------|---------|
| 1 | Pack | ₹99 | ₹99 | — |
| 2 | Packs | ₹180 | ₹90 | 9.1% |
| 5 | Packs | ₹420 | ₹84 | **15.2%** ⭐ Best Value |
| 10 | Packs | ₹770 | ₹77 | **22.2%** Bulk |

---

## Implementation Guide

### 1. PricingTierModel

Type-safe model with serialization and calculations:

```dart
final tier = PricingTierModel(
  id: 'tier_1',
  quantity: 5,
  unit: 'KG',
  price: 280,
  isDefault: false,
);

// Calculations
double savings = tier.calculateSavings(249); // basePrice=249
double pricePerUnit = tier.getPricePerUnit();

// Serialization
Map<String, dynamic> data = tier.toFirestore();
PricingTierModel restored = PricingTierModel.fromFirestore(id, data);
```

### 2. PricingService

Complete Firestore operations:

```dart
final service = PricingService();

// Fetch
List<PricingTierModel> tiers = await service.getPricingTiers(productId);

// Watch (real-time)
service.watchPricingTiers(productId).listen((tiers) {
  print('Tiers updated: ${tiers.length}');
});

// CRUD
await service.createPricingTier(productId, tier);
await service.updatePricingTier(productId, tierId, {'price': 299});
await service.deletePricingTier(productId, tierId);

// Set default
await service.setDefaultTier(productId, tierId);

// Bulk operations
await service.bulkCreatePricingTiers(productId, [tier1, tier2, tier3]);
await service.deleteAllPricingTiers(productId);

// Best value
PricingTierModel? best = await service.getBestValueTier(productId, basePrice);
```

### 3. UI Components

#### PricingTiersWidget (Table View)
```dart
PricingTiersWidget(
  tiers: tiers,
  basePrice: 249,
  bestValueTierId: 'tier_3',
  isEditable: false,
)
```

Features:
- Full pricing table with all details
- Savings percentage with colored badges
- Best value highlighting
- Sorted by quantity ascending

#### PricingTierCard (Single Card)
```dart
PricingTierCard(
  tier: tier,
  basePrice: 249,
  isBestValue: true,
  onTap: () => print('Selected tier'),
)
```

Features:
- Compact tier display
- "Best Value" badge if applicable
- Tap handling for selection

#### PricingTiersScroll (Horizontal List)
```dart
PricingTiersScroll(
  tiers: tiers,
  basePrice: 249,
  bestValueTierId: 'tier_3',
  onTierSelected: (tier) => selectQuantity(tier),
)
```

Features:
- Horizontal scrolling for multiple tiers
- Card-based display
- Selection callback

### 4. Admin Management Screen

```dart
ManagePricingScreen(
  productId: 'product_1',
  productName: 'Face Wash',
  basePrice: 249,
)
```

**Features:**
- ✅ View all pricing tiers with real-time updates
- ✅ Add new pricing tier with quantity/unit/price
- ✅ Edit existing pricing tier
- ✅ Delete pricing tier
- ✅ Set default tier
- ✅ Automatic savings calculation
- ✅ Input validation

---

## Integration with ProductDetailScreen

### Step 1: Update imports
```dart
import 'package:slvh_app/features/products/services/pricing_service.dart';
import 'package:slvh_app/features/products/widgets/pricing_tiers_widget.dart';
```

### Step 2: Initialize service
```dart
final _pricingService = PricingService();
```

### Step 3: Fetch and display tiers
```dart
// Get best value tier
final bestValueTier = await _pricingService.getBestValueTier(
  widget.productId,
  product.price,
);

// Display in UI
FutureBuilder<List<PricingTierModel>>(
  future: _pricingService.getPricingTiers(widget.productId),
  builder: (context, snapshot) {
    final tiers = snapshot.data ?? [];
    if (tiers.isEmpty) return const SizedBox.shrink();
    
    return PricingTiersWidget(
      tiers: tiers,
      basePrice: product.price,
      bestValueTierId: bestValueTier?.id,
      isEditable: false,
    );
  },
)
```

### Step 4: Update quantity selection

```dart
// Quantity selector with tier presets
StreamBuilder<List<PricingTierModel>>(
  stream: _pricingService.watchPricingTiers(widget.productId),
  builder: (context, snapshot) {
    final tiers = snapshot.data ?? [];
    return Column(
      children: [
        // Quick tier selection
        PricingTiersScroll(
          tiers: tiers,
          basePrice: product.price,
          onTierSelected: (tier) {
            setState(() {
              _selectedQuantity = tier.quantity.toInt();
            });
          },
        ),
        const SizedBox(height: 16),
        // Manual quantity selector
        _buildQuantitySelector(),
      ],
    );
  },
)
```

---

## Integration with Admin Dashboard

### Add menu item
```dart
// In admin dashboard menu
ListTile(
  leading: const Icon(Icons.price_change),
  title: const Text('Pricing Tiers'),
  onTap: () => context.push(
    '/admin/pricing/${productId}',
    extra: productName,
  ),
)
```

### Add route
```dart
// In app_router.dart
GoRoute(
  path: '/admin/pricing/:productId',
  builder: (context, state) {
    final productId = state.pathParameters['productId']!;
    final productName = state.extra as String? ?? 'Product';
    return ManagePricingScreen(
      productId: productId,
      productName: productName,
      basePrice: 249, // Get from product
    );
  },
)
```

---

## Key Features Explained

### 1. **Automatic Savings Calculation**
```dart
double savings = tier.calculateSavings(basePrice);
// (basePrice - pricePerUnit) / basePrice * 100
// Returns percentage saved
```

### 2. **Best Value Highlighting**
```dart
// Automatically identifies tier with highest savings
PricingTierModel? best = await service.getBestValueTier(productId, basePrice);
// Used for visual highlighting in UI
```

### 3. **Price Per Unit**
```dart
double pricePerUnit = tier.getPricePerUnit();
// Calculates: price / quantity
// Shows customer the actual unit cost
```

### 4. **Default Tier**
```dart
// When a tier is set as default, all others become non-default
await service.setDefaultTier(productId, tierId);
// Uses batch operation for atomic update
```

### 5. **Real-Time Updates**
```dart
// All streams automatically update when tiers change
service.watchPricingTiers(productId).listen((tiers) {
  // UI rebuilds instantly
});
```

---

## Testing Guide

### Manual Testing Steps

1. **Add Pricing Tiers**
   - Navigate to product management
   - Select a product
   - Click "Pricing Tiers"
   - Add 3 tiers with different quantities
   - Verify savings % calculated correctly

2. **Test UI Display**
   - Open ProductDetailScreen
   - Verify all tiers display in table
   - Check savings percentage shows correctly
   - Verify best value is highlighted

3. **Test Selection**
   - Click on pricing tiers
   - Verify quantity selector updates
   - Check price updates based on selection

4. **Test Admin Operations**
   - Edit a tier (change price)
   - Delete a tier
   - Set default tier
   - Verify real-time updates

5. **Edge Cases**
   - No pricing tiers (show base price only)
   - Single tier (disable tier selection)
   - Many tiers (verify horizontal scroll)

### Firestore Verification
```
products/
└── product_1/
    └── pricing_tiers/
        ├── tier_1: {quantity: 1, unit: "KG", price: 249, isDefault: true}
        ├── tier_2: {quantity: 5, unit: "KG", price: 1100, isDefault: false}
        └── tier_3: {quantity: 10, unit: "KG", price: 2100, isDefault: false}
```

---

## Performance Tips

1. **Lazy Load Tiers**
   - Only fetch tiers when product detail screen opens
   - Use FutureBuilder + Stream for efficiency

2. **Cache Best Value**
   - Calculate once and store temporarily
   - Recalculate only when tiers change

3. **Batch Operations**
   - Use `bulkCreatePricingTiers` for multiple tiers
   - Reduces Firestore write operations

4. **Limit Tiers**
   - Keep to 4-6 tiers per product
   - More tiers = slower performance

---

## Sample Seeding Script

For Firebase Console, create tiers manually:

1. Go to Firestore → products → {productId} → pricing_tiers
2. Add documents with these values:

**Face Wash Product (Quantity-Based):**
```
Doc ID: auto
- quantity: 1
- unit: Piece
- price: 249
- isDefault: true
```

**Cooking Oil Product (Volume-Based):**
```
Doc ID: auto
- quantity: 5
- unit: L
- price: 1595
- isDefault: false
```

---

## Next Steps

- ✅ Implement pricing tiers UI in ProductDetailScreen
- ✅ Add tier selection to shopping cart
- ✅ Show tier-based pricing in cart summary
- ✅ Send selected tier with product to checkout
- 🔜 Analytics: Track tier popularity
- 🔜 Seasonal pricing adjustments
- 🔜 Promotional tier discounts

---

✅ **Dynamic Pricing Module - Complete & Production-Ready!**
