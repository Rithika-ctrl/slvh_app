# Firebase Setup Guide for Smart Shop App

## Overview
Firebase provides the backend for your Smart Shop application. This guide walks you through setting up all required Firebase services.

---

## PART 1: Create Firebase Project

### Step 1: Go to Firebase Console
1. Open browser and go to: https://console.firebase.google.com/
2. Sign in with your Google account (create one if needed)

### Step 2: Create Project
1. Click "Create a project"
2. Project name: `SmartShop`
3. Click "Continue"
4. Toggle OFF: "Enable Google Analytics"
5. Click "Create project"
6. Wait for project creation (2-3 minutes)

---

## PART 2: Enable Firebase Services

### Service 1: Firestore Database

**Purpose:** Store products, orders, users, pricing data

1. Click "Firestore Database" in left sidebar
2. Click "Create database"
3. Settings:
   - **Security rules:** Start in production mode
   - **Location:** `asia-south1` (Closest to India)
4. Click "Create"
5. Wait for database creation

### Configure Firestore Collections (Manual)
After Firestore is created, you'll create these collections. For now, just note these collection names:

```
users/
  - uid (auto)
    - phoneNumber
    - name
    - role (customer/admin)
    - createdAt

products/
  - productId (auto)
    - name
    - description
    - category
    - images: []
    - stock
    - unitType
    - active

pricing_tiers/
  - tierId (auto)
    - productId
    - quantity
    - price

orders/
  - orderId (auto)
    - customerId
    - items: []
    - total
    - status
    - paymentStatus
    - pickupSlot
    - createdAt

settings/
  - businessSettings (document)
    - shopOpenTime
    - shopCloseTime
    - pickupStartTime
    - pickupEndTime
    - delayHours
    - slotDuration
    - holidayMode
    - upiId
```

### Service 2: Realtime Database (Optional)

**Purpose:** Real-time notifications and live updates

1. Click "Realtime Database" in left sidebar
2. Click "Create Database"
3. Settings:
   - **Location:** `asia-south1`
   - **Security rules:** Locked mode
4. Click "Create"

### Service 3: Cloud Storage

**Purpose:** Store product images and payment screenshots

1. Click "Storage" in left sidebar
2. Click "Get started"
3. Security rules: Use default
4. **Location:** `asia-south1`
5. Click "Done"

### Service 4: Cloud Functions

**Purpose:** Serverless backend for WhatsApp notifications and automations

1. Click "Functions" in left sidebar
2. Click "Get started"
3. Select region: `asia-south1`
4. Click "Next"
5. Click "Deploy"

### Service 5: Authentication

1. Click "Authentication" in left sidebar
2. Click "Get started"
3. Enable sign-in methods:
   - **Phone:** Click "Phone" → Enable
   - **Email/Password:** Click "Email/Password" → Enable
4. For phone auth, you may need to add test numbers later

---

## PART 3: Create Web App Configuration

### Step 1: Register Web App
1. Go to Project Settings (gear icon top right)
2. Click "Your apps" tab
3. Under "Web apps" section, click `</>` icon
4. App name: `SmartShop Web Admin`
5. Check "Also set up Firebase Hosting"
6. Click "Register app"

### Step 2: Get Firebase Config
You'll see Firebase config like this:
```javascript
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "smartshop-xxxxx.firebaseapp.com",
  projectId: "smartshop-xxxxx",
  storageBucket: "smartshop-xxxxx.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdefg"
};
```

**Save this config!** You'll need it for your Flutter app.

### Step 3: Continue Setup
- Click "Next"
- Click "Install Firebase CLI"
- Click "Next"
- Click "Go to console"

---

## PART 4: Create Android App Configuration

### Step 1: Register Android App
1. Go to Project Settings → "Your apps" tab
2. Click Android icon `()`
3. Fill in:
   - **Package name:** `com.smartshop.app` (or your choice)
   - **App name:** `SmartShop`
   - **Debug certificate (optional for now):** Leave blank
4. Click "Register app"

### Step 2: Download google-services.json
1. Click "Download google-services.json"
2. **Save this file!** Keep it in a safe location
3. You'll need to copy it to your Flutter project later:
   - Path: `android/app/google-services.json`

### Step 3: Configure Android App
- Click "Next" through the configuration steps
- Click "Go to console"

---

## PART 5: Database Security Rules

### Firestore Security Rules

Go to Firestore → Rules tab and replace with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Allow users to read/write their own data
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    
    // Allow customers to read all products
    match /products/{document=**} {
      allow read: if true;
      allow write: if request.auth.token.admin == true;
    }
    
    // Allow users to read pricing tiers
    match /pricing_tiers/{document=**} {
      allow read: if true;
      allow write: if request.auth.token.admin == true;
    }
    
    // Allow customers to create/read their own orders
    match /orders/{orderId} {
      allow create: if request.auth != null;
      allow read: if request.auth.uid == resource.data.customerId;
      allow update: if request.auth.token.admin == true;
    }
    
    // Allow admin to read/write settings
    match /settings/{document=**} {
      allow read, write: if request.auth.token.admin == true;
    }
    
    // Allow reading analytics (admin only)
    match /analytics/{document=**} {
      allow read, write: if request.auth.token.admin == true;
    }
  }
}
```

---

## PART 6: Storage Security Rules

Go to Storage → Rules tab and replace with:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Allow authenticated users to read all files
    match /{allPaths=**} {
      allow read: if request.auth != null;
    }
    
    // Allow admin to write files
    match /products/{allPaths=**} {
      allow write: if request.auth.token.admin == true;
    }
    
    match /payments/{allPaths=**} {
      allow write: if request.auth != null;
    }
    
    match /banners/{allPaths=**} {
      allow write: if request.auth.token.admin == true;
    }
  }
}
```

---

## PART 7: Flutter Configuration

### Step 1: Add Firebase Dependencies

Open `pubspec.yaml` in your Flutter project and add:

```yaml
dependencies:
  firebase_core: ^2.24.2
  cloud_firestore: ^4.13.6
  firebase_auth: ^4.14.0
  firebase_storage: ^11.5.6
  firebase_messaging: ^14.7.0
  provider: ^6.1.0
```

### Step 2: Run pub get

```powershell
flutter pub get
```

### Step 3: Initialize Firebase in main.dart

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}
```

### Step 4: Add google-services.json

1. Copy the `google-services.json` file you downloaded
2. Paste it in: `android/app/google-services.json`

### Step 5: Update Android Build Files

In `android/app/build.gradle`, add:

```gradle
plugins {
    id 'com.android.application'
    id 'com.google.gms.google-services'
    id 'kotlin-android'
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.3.1')
}
```

In `android/build.gradle`, add:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

---

## PART 8: Test Firebase Connection

Create a test function in your Flutter app:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> testFirebase() async {
  try {
    final db = FirebaseFirestore.instance;
    
    // Create test collection
    await db.collection('test').add({
      'message': 'Firebase is working!',
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    print('✓ Firebase connection successful!');
  } catch (e) {
    print('✗ Firebase error: $e');
  }
}
```

Run this function on app startup to verify Firebase is connected.

---

## PART 9: Enable Google Analytics (Optional)

1. Go to Project Settings → Integrations tab
2. Click on Google Analytics
3. Follow the setup wizard
4. This helps track app usage and performance

---

## PART 10: Backup & Recovery

### Enable Backups
1. Go to Firestore Database
2. Click "Backups" tab
3. Enable automated backups

### Export Data
You can export Firestore data via:
```
gcloud firestore export gs://bucket-name/backup-folder
```

---

## IMPORTANT CONFIGURATIONS

### Add Admin User (Custom Claims)

Set this up so admins have special privileges:

```dart
// In Firebase Console, use Cloud Functions or custom code
// to set custom claims for admin users

Map<String, dynamic> adminClaims = {
  'admin': true,
};
```

### Enable Offline Persistence

In your Flutter app's main.dart:

```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
);
```

---

## COMMON FIREBASE OPERATIONS IN FLUTTER

### Add Document
```dart
await FirebaseFirestore.instance
    .collection('products')
    .add({
  'name': 'Rice',
  'price': 60,
  'stock': 100,
});
```

### Read Document
```dart
var doc = await FirebaseFirestore.instance
    .collection('products')
    .doc('productId')
    .get();
```

### Update Document
```dart
await FirebaseFirestore.instance
    .collection('products')
    .doc('productId')
    .update({'stock': 95});
```

### Delete Document
```dart
await FirebaseFirestore.instance
    .collection('products')
    .doc('productId')
    .delete();
```

### Real-time Listener
```dart
FirebaseFirestore.instance
    .collection('orders')
    .where('customerId', isEqualTo: userId)
    .snapshots()
    .listen((snapshot) {
  for (var doc in snapshot.docs) {
    print(doc['orderId']);
  }
});
```

---

## TROUBLESHOOTING

### "Firebase is not initialized"
- Make sure `Firebase.initializeApp()` is called in main.dart
- Add `WidgetsFlutterBinding.ensureInitialized()` before Firebase init

### "google-services.json not found"
- Verify file is in `android/app/google-services.json`
- Rebuild app: `flutter clean && flutter pub get`

### "Permission denied" errors
- Check Firestore security rules
- Make sure user is authenticated before firestore operations
- Check custom claims are set for admin operations

### "Connection timeout"
- Check internet connection
- Verify Firebase project is active
- Check firewall/VPN settings

---

## NEXT STEPS

1. ✅ Create Firebase project
2. ✅ Enable all services
3. ✅ Get Firebase config
4. ✅ Download google-services.json
5. Start building authentication module
6. Create database collections
7. Build product listing
8. Implement orders system

---

**Firebase is now ready for your Smart Shop App! 🚀**

For more help: https://firebase.google.com/docs/flutter/setup
