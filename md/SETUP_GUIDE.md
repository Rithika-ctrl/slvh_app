# Complete Smart Shop App Setup Guide - Windows

This guide will help you install all required tools and set up your development environment.

---

## STEP 1: Install Java Development Kit (JDK 17)

**Why:** Android development requires Java

### Download & Install
1. Go to: https://www.oracle.com/java/technologies/downloads/#java17
2. Download **JDK 17 Windows Installer** (x64)
3. Run the installer (.exe file)
4. Follow the installation wizard
5. **Important:** Note the installation path (usually `C:\Program Files\Java\jdk-17.x.x`)

### Verify Installation
After installation, open PowerShell and run:
```powershell
java -version
```
You should see Java version 17.x.x

---

## STEP 2: Install Android Studio

**Why:** Provides Android SDK and emulator

### Download & Install
1. Go to: https://developer.android.com/studio
2. Click "Download Android Studio"
3. Run the installer (.exe file)
4. Follow the setup wizard with these settings:
   - Choose "Standard" installation
   - Accept all default locations
   - Install Android SDK
   - Install Android Emulator

### First-Time Setup
1. Open Android Studio after installation
2. Go to: Tools → SDK Manager
3. Install the following:
   - **SDK Platforms:** Android 13 (API 33) - minimum
   - **SDK Tools:** 
     - Android SDK Build-Tools 34.x.x
     - Android Emulator
     - Android SDK Platform-Tools
4. Accept licenses and download

### Create Android Virtual Device (Emulator)
1. Tools → Device Manager
2. Click "Create Device"
3. Select "Pixel 4" or "Pixel 5"
4. Choose Android 13 (API 33)
5. Click "Finish"

---

## STEP 3: Set Up Environment Variables

**Why:** Flutter needs to find Android SDK and Java

### Windows Environment Variables
1. Press `Windows Key + X` → System
2. Click "Advanced system settings" on the right
3. Click "Environment Variables" button
4. Click "New" under User variables

### Add ANDROID_HOME
- **Variable name:** `ANDROID_HOME`
- **Variable value:** `C:\Users\YourUsername\AppData\Local\Android\Sdk`
  (Replace YourUsername with your Windows username)

### Add JAVA_HOME
- **Variable name:** `JAVA_HOME`
- **Variable value:** `C:\Program Files\Java\jdk-17.x.x`
  (Use your actual JDK installation path)

### Update PATH
1. Find "Path" variable → Click "Edit"
2. Click "New" and add:
   - `C:\Users\YourUsername\AppData\Local\Android\Sdk\platform-tools`
   - `C:\Users\YourUsername\AppData\Local\Android\Sdk\tools`

3. Click OK and close all windows

**Restart your computer** for changes to take effect.

---

## STEP 4: Install Flutter SDK

**Why:** Flutter framework for app development

### Download & Install
1. Go to: https://flutter.dev/docs/get-started/install/windows
2. Download **Flutter SDK for Windows**
3. Extract the ZIP file to a location like: `C:\src\flutter`
   (Create the folders if they don't exist)

### Add Flutter to PATH
1. Open Environment Variables again (Windows Key + X → System)
2. Edit "Path" variable
3. Click "New" and add: `C:\src\flutter\bin`
   (Or your actual Flutter path)
4. Click OK

**Restart your computer again** for changes to take effect.

### Verify Flutter Installation
Open PowerShell and run:
```powershell
flutter --version
dart --version
```
Both should show version numbers.

### Run Flutter Doctor
```powershell
flutter doctor
```
This checks your setup. It's OK if Android licenses show warnings.

### Accept Android Licenses
```powershell
flutter doctor --android-licenses
```
Type "y" and press Enter for all prompts.

---

## STEP 5: Install Git

**Why:** Version control for your project

### Download & Install
1. Go to: https://git-scm.com/download/win
2. Download Git for Windows
3. Run the installer
4. Use all default settings (click Next → Finish)

### Verify Installation
```powershell
git --version
```

---

## STEP 6: Install VS Code Extensions

**Why:** Better Flutter development experience

1. Open VS Code
2. Click Extensions icon (left sidebar)
3. Search and install:
   - **Flutter** (by Dart Code)
   - **Dart** (by Dart Code)
   - **Firebase** (optional but recommended)

---

## STEP 7: Set Up Firebase Project

**Why:** Backend for your app

### Create Firebase Project
1. Go to: https://console.firebase.google.com/
2. Click "Create a project"
3. Project name: `SmartShop`
4. Click "Create project"
5. Wait for project creation

### Enable Services
1. Click "Firestore Database" → "Create database"
   - Start in production mode
   - Region: asia-south1 (closest to India)
2. Click "Realtime Database" → "Create Database"
   - Region: asia-south1
   - Start in locked mode
3. Click "Storage" → "Get started"

### Create Web App
1. Click "Project Settings" (gear icon)
2. Click "Your apps" tab
3. Click Web icon (`</>``)
4. App name: `SmartShop Web`
5. Click "Register app"
6. **Copy the Firebase config** (save it for later)
7. Click "Continue to console"

### Create Android App
1. Back in Project Settings → "Your apps"
2. Click Android icon
3. Package name: `com.shop.smartshop`
4. App name: `SmartShop`
5. Click "Register app"
6. Download `google-services.json`
7. **Keep this file safe** (you'll need it later)

---

## STEP 8: Create Your First Flutter Project

Open PowerShell in your project folder and run:

```powershell
flutter create smart_shop_app
cd smart_shop_app
flutter pub get
```

---

## STEP 9: Test Everything Works

### Run on Emulator
```powershell
flutter emulators --launch Pixel_4_API_33
```

Wait for emulator to start, then run:
```powershell
flutter run
```

You should see the Flutter demo app on the emulator.

---

## STEP 10: Configure Firebase in Your Project

1. Add Firebase dependencies to `pubspec.yaml`
2. Initialize Firebase in `main.dart`
3. Add `google-services.json` to Android folder

---

## TROUBLESHOOTING

### "flutter command not found"
- Restart PowerShell
- Check if Flutter path is in Environment Variables
- Restart your computer

### "Android SDK not found"
- Check ANDROID_HOME variable points to correct path
- Run `flutter doctor` to see missing SDKs
- Install missing SDKs through Android Studio

### "Emulator won't start"
- Check Android Studio → Device Manager
- Make sure virtual device is created
- Restart Android Studio

### "Java version mismatch"
- Use Java 17+ for Android development
- Set JAVA_HOME to correct JDK path

---

## NEXT STEPS

Once everything is installed:

1. ✅ Create Flutter project
2. ✅ Set up Firebase
3. ✅ Test app on emulator
4. ✅ Start building modules

---

## Quick Command Reference

```powershell
# Check versions
flutter --version
dart --version
java -version
git --version

# Create project
flutter create project_name

# Run app
flutter run

# Run on specific device
flutter run -d device_id

# Build APK for release
flutter build apk --release

# View all devices
flutter devices

# Start Flutter emulator
flutter emulators --launch emulator_name
```

---

## ESTIMATED TIME
- Java: 10 minutes
- Android Studio + SDK: 30 minutes
- Flutter: 10 minutes
- Environment setup: 10 minutes
- Firebase setup: 15 minutes
- **Total: ~75 minutes**

---

**You're now ready to start building the Smart Shop App! 🚀**
