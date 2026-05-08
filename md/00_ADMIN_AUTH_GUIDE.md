# Admin Authentication System - Complete Guide

## Overview

The admin authentication system uses **email and password authentication** with role-based access control through Firestore. The current implementation uses **fake credentials** for development.

---

## Current Development Setup (Fake)

### Fake Admin Credentials
- **Email:** `admin@smartshop.com`
- **Password:** `admin123`

### How It Works (Development)
1. User enters email and password on admin login screen
2. Credentials are checked against hardcoded values (`FAKE_ADMIN_EMAIL` and `FAKE_ADMIN_PASSWORD`)
3. If match, login state is saved to SharedPreferences
4. User is redirected to admin dashboard
5. AuthWrapper on app startup checks admin login status and routes accordingly

### Code Location
- **Login Screen:** [lib/features/auth/screens/admin_login_screen.dart](lib/features/auth/screens/admin_login_screen.dart)
- **Dashboard:** [lib/features/auth/screens/admin_dashboard.dart](lib/features/auth/screens/admin_dashboard.dart)
- **Auth Service:** [lib/features/auth/services/auth_service.dart](lib/features/auth/services/auth_service.dart)
- **Router:** [lib/routes/app_router.dart](lib/routes/app_router.dart)
- **App Entry:** [lib/app.dart](lib/app.dart)

---

## Migration to Real Firebase Authentication

### Step 1: Prepare Firebase Project

```bash
# Install Firebase CLI (if not installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Connect to your Firebase project
firebase use --add
```

### Step 2: Update auth_service.dart

Replace the `adminLogin()` method with real Firebase code:

```dart
/// Admin login with email and password (Firebase)
Future<bool> adminLogin({
  required String email,
  required String password,
  required Function(String errorMessage) onError,
}) async {
  try {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    
    // Sign in with email and password
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Get user role from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .get();

    final userRole = userDoc.data()?['role'] ?? '';

    // Verify user is admin
    if (userRole != 'admin') {
      await _auth.signOut();
      onError('You do not have admin access');
      return false;
    }

    // Save admin login state
    await _saveAdminLoginState(email);
    return true;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      onError('No user found with that email');
    } else if (e.code == 'wrong-password') {
      onError('Wrong password');
    } else {
      onError('Authentication failed: ${e.message}');
    }
    return false;
  } catch (e) {
    onError('Login failed: ${e.toString()}');
    return false;
  }
}
```

### Step 3: Create Firebase Users Collection

In **Firebase Console** (Firestore):

1. Create a collection named `users`
2. Create documents with this structure:

```
Collection: users
├── Document ID: [user_uid]
│   ├── email: "admin@smartshop.com"
│   ├── role: "admin"
│   ├── createdAt: Timestamp
│   └── name: "Shop Owner"
├── Document ID: [another_user_uid]
│   ├── email: "customer@example.com"
│   ├── role: "customer"
│   └── createdAt: Timestamp
```

### Step 4: Create Admin User in Firebase

1. Go to **Firebase Console** → **Authentication**
2. Click **Create user**
3. Enter email and password
4. Get the User UID
5. Go to **Firestore** → **users** collection
6. Create a document with ID = User UID
7. Add these fields:
   - `email`: admin@smartshop.com
   - `role`: admin
   - `createdAt`: (timestamp)
   - `name`: Shop Owner

### Step 5: Update Admin Password (Optional)

In Firebase Console → Authentication:
1. Select the admin user
2. Click the three dots menu
3. Choose **Edit password**
4. Enter new password

---

## Admin User Structure (Firestore)

### Document Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | String | ✓ | Admin email address |
| `role` | String | ✓ | Must be "admin" for access |
| `name` | String | ✓ | Full name of admin |
| `createdAt` | Timestamp | ✓ | Account creation date |
| `lastLogin` | Timestamp | Optional | Last login timestamp |
| `phone` | String | Optional | Contact number |
| `shopName` | String | Optional | Associated shop name |

### Example Document
```json
{
  "email": "admin@smartshop.com",
  "role": "admin",
  "name": "Sanjay Kumar",
  "createdAt": "2024-01-15T10:30:00Z",
  "lastLogin": "2024-01-20T15:45:00Z",
  "phone": "+919876543210",
  "shopName": "Smart Shop"
}
```

---

## Testing the Admin Login

### Current (Development) Testing

```bash
# Build web app
flutter build web

# Run on Chrome
flutter run -d chrome

# Test Admin Login
1. Click "Admin Access" button on home page
2. Enter email: admin@smartshop.com
3. Enter password: admin123
4. Click "LOGIN AS ADMIN"
5. You should see the admin dashboard
```

### After Firebase Migration

```bash
# Same steps, but credentials will be verified against Firebase
# And role will be checked in Firestore
```

---

## Security Considerations

### Current (Fake) Implementation
⚠️ **Not secure for production** - credentials are hardcoded

### For Production (Firebase)
✓ Passwords are securely hashed by Firebase  
✓ Role verification through Firestore  
✓ Email verification can be enabled  
✓ Multi-factor authentication (MFA) available  
✓ Session tokens handled by Firebase  

### Recommended Security Practices

1. **Email Verification**
```dart
if (!userCredential.user!.emailVerified) {
  await userCredential.user!.sendEmailVerification();
  onError('Please verify your email address');
  return false;
}
```

2. **Rate Limiting**
Implement Firebase Security Rules to limit login attempts:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{document=**} {
      allow read, update, delete: if request.auth.uid == resource.data.uid && resource.data.role == 'admin';
      allow create: if false; // Only create via Firebase Admin SDK
    }
  }
}
```

3. **Session Timeout**
Implement automatic logout after 30 minutes of inactivity

4. **Logging**
Log all admin login attempts for security audits

---

## Admin Dashboard Features

### Current Features (Placeholders)
- ✓ Quick stats display (Orders, Revenue, Customers, Conversion)
- ✓ Management menu cards (Orders, Products, Customers, Settings)
- ✓ Admin email display
- ✓ Logout functionality

### Planned Features
- [ ] Order management and tracking
- [ ] Product CRUD operations
- [ ] Customer list and analytics
- [ ] Sales reports and charts
- [ ] Inventory management
- [ ] Admin settings and preferences
- [ ] Shop configuration

---

## Troubleshooting

### "Invalid email or password"
- **Current:** Check if credentials match `admin@smartshop.com` and `admin123`
- **Firebase:** Verify user exists in Firebase Authentication and Firestore

### "You do not have admin access"
- Check that the user document in Firestore has `role: "admin"`
- Verify the document is in the `users` collection

### "Session expired"
- SharedPreferences login state might be corrupted
- Try clearing app data and logging in again

### Cannot redirect to admin dashboard after login
- Check `lib/app.dart` AuthWrapper implementation
- Verify SharedPreferences keys match: `admin_logged_in` and `admin_email`

---

## API Reference

### AuthService Methods

#### `adminLogin()`
```dart
Future<bool> adminLogin({
  required String email,
  required String password,
  required Function(String errorMessage) onError,
}) async
```
- Authenticates admin with email and password
- Returns `true` on success, `false` on failure
- Calls `onError` callback with error message

#### `isAdminLoggedIn()`
```dart
Future<bool> isAdminLoggedIn() async
```
- Checks if admin is currently logged in
- Returns `true` if admin session exists

#### `getCurrentAdminEmail()`
```dart
Future<String?> getCurrentAdminEmail() async
```
- Returns the logged-in admin's email
- Returns `null` if not logged in

#### `signOut()`
```dart
Future<void> signOut() async
```
- Logs out both customer and admin
- Clears all session data from SharedPreferences

---

## Next Steps

1. **Set up Firebase project** (if not already done)
2. **Create admin user** in Firebase Console
3. **Update auth_service.dart** with real Firebase code
4. **Test admin login** with real credentials
5. **Implement remaining dashboard features**
6. **Set up Firebase Security Rules** for production
7. **Enable email verification** for enhanced security

---

## Related Files

- [00_START_HERE.md](../00_START_HERE.md) - Project overview
- [FIREBASE_SETUP.md](../FIREBASE_SETUP.md) - Firebase configuration
- [SETUP_GUIDE.md](../SETUP_GUIDE.md) - Initial setup instructions
- [complete_detailed_build_guide_smart_shop_app.md](../complete_detailed_build_guide_smart_shop_app.md) - Detailed build guide
