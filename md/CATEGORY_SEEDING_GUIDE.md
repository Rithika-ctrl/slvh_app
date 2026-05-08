# 📂 Category Seeding Guide

This guide shows how to manually seed **5+ product categories** into Firebase Firestore for the SLVH Smart Shop.

## Prerequisites
- Firebase project set up
- Access to Firebase Console
- The following category data ready

---

## Firestore Collection Structure

**Collection Path:** `categories`

**Document Schema:**
```json
{
  "name": "string",
  "description": "string",
  "imageUrl": "string (URL or local path)",
  "sortOrder": "integer",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

---

## 5+ Product Categories to Seed

### Category 1: Personal Care
- **Name:** Personal Care
- **Description:** Face, skin, and body care products
- **Image URL:** https://images.unsplash.com/photo-1556228578-8c89e6adf883?w=400
- **Sort Order:** 1

### Category 2: Cleaning Supplies
- **Name:** Cleaning Supplies
- **Description:** Disinfectants, floor cleaners, and detergents
- **Image URL:** https://images.unsplash.com/photo-1584262407984-ab60ae0a1484?w=400
- **Sort Order:** 2

### Category 3: Soaps & Bath
- **Name:** Soaps & Bath
- **Description:** Premium soaps, shampoos, and bath products
- **Image URL:** https://images.unsplash.com/photo-1556228578-8c89e6adf883?w=400
- **Sort Order:** 3

### Category 4: Kitchen & Dining
- **Name:** Kitchen & Dining
- **Description:** Kitchen essentials and dining accessories
- **Image URL:** https://images.unsplash.com/photo-1578500494198-246f612d03b3?w=400
- **Sort Order:** 4

### Category 5: Paper Products
- **Name:** Paper Products
- **Description:** Tissues, paper towels, and napkins
- **Image URL:** https://images.unsplash.com/photo-1584839379341-c74e27e9c89f?w=400
- **Sort Order:** 5

### Category 6: Beverages
- **Name:** Beverages
- **Description:** Juices, drinks, and refreshments
- **Image URL:** https://images.unsplash.com/photo-1599599810694-b5ac4dd3e900?w=400
- **Sort Order:** 6

---

## How to Seed Categories

### **Option A: Firebase Console (Manual)**

1. Go to **Firebase Console** → Select your project
2. Navigate to **Firestore Database**
3. Click **+ Start Collection**
4. Enter collection name: `categories`
5. Click **Next**
6. Click **+ Add Document**
7. Enter the first category's data:
   - Document ID: `category_1` (or auto-generate)
   - Add fields:
     - `name`: "Personal Care"
     - `description`: "Face, skin, and body care products"
     - `imageUrl`: (paste URL)
     - `sortOrder`: 1
     - `createdAt`: (server timestamp)
     - `updatedAt`: (server timestamp)

8. Click **Save**
9. Repeat for all 6 categories

### **Option B: Cloud Functions / CLI (Automated)**

Create a script in your `lib/scripts/seed_categories.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedCategories() async {
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();

  final categories = [
    {
      'name': 'Personal Care',
      'description': 'Face, skin, and body care products',
      'imageUrl': 'https://images.unsplash.com/photo-1556228578-8c89e6adf883?w=400',
      'sortOrder': 1,
    },
    {
      'name': 'Cleaning Supplies',
      'description': 'Disinfectants, floor cleaners, and detergents',
      'imageUrl': 'https://images.unsplash.com/photo-1584262407984-ab60ae0a1484?w=400',
      'sortOrder': 2,
    },
    // ... add remaining categories
  ];

  int index = 1;
  for (var cat in categories) {
    batch.set(
      firestore.collection('categories').doc('category_$index'),
      {
        ...cat,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    index++;
  }

  await batch.commit();
  print('✅ ${categories.length} categories seeded!');
}
```

---

## Verification Checklist

After seeding, verify:

- [ ] **6 documents** in the `categories` collection
- [ ] Each document has: name, description, imageUrl, sortOrder, createdAt, updatedAt
- [ ] All **sortOrder** values are unique (1-6)
- [ ] All **imageUrls** are valid and accessible
- [ ] Run the app and see categories on HomeScreen

---

## Testing

1. Start the app
2. Navigate to **HomeScreen**
3. Scroll to **"Shop by Category"** section
4. Verify **6 category cards** appear with:
   - ✅ Category images loaded
   - ✅ Category names visible
   - ✅ Descriptions showing
   - ✅ Cards are clickable
   - ✅ Proper sorting order

---

## Troubleshooting

**Issue:** Categories not appearing on HomeScreen?
- Check Firestore permissions (Cloud Firestore should allow read access)
- Verify collection name is exactly `categories` (case-sensitive)
- Check internet connectivity

**Issue:** Images not loading?
- Verify image URLs are accessible from your device
- Check if URLs return valid images
- Use HTTPS URLs only

**Issue:** Wrong sort order?
- Check `sortOrder` field values in Firestore
- Ensure they're integers (not strings)

---

## Next Steps

Once seeding is complete:
1. ✅ Categories display on HomeScreen
2. 🔜 Create Products collection linked to Categories
3. 🔜 Build product filtering by category
4. 🔜 Implement admin product management
