# Smart Shop App - Installation Quick Links & Reference

## 🔗 DIRECT DOWNLOAD LINKS

### Java Development Kit 17
- **Official Link:** https://www.oracle.com/java/technologies/downloads/#java17
- **Direct Download (Windows x64):** https://download.oracle.com/java/17/latest/jdk-17_windows-x64_bin.exe
- **File Size:** ~170 MB
- **Installation Time:** 5-10 minutes

### Android Studio
- **Official Link:** https://developer.android.com/studio
- **Direct Download:** https://redirector.gstatic.com/android/studio/install/2024.1.1.8/android-studio-2024.1.1.8-windows.exe
- **File Size:** ~650 MB
- **Installation Time:** 20-30 minutes
- **Additional SDK download:** 5-10 GB (happens during first setup)

### Flutter SDK
- **Official Link:** https://flutter.dev/docs/get-started/install/windows
- **Direct Download:** https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.22.2-stable.zip
- **File Size:** ~720 MB
- **Installation Time:** 5 minutes (no separate installer, just extract)

### Git for Windows
- **Official Link:** https://git-scm.com/download/win
- **Direct Download:** https://github.com/git-for-windows/git/releases/download/v2.45.0.windows.1/Git-2.45.0-64-bit.exe
- **File Size:** ~50 MB
- **Installation Time:** 3-5 minutes

### VS Code
- **Official Link:** https://code.visualstudio.com/
- **Direct Download (Windows):** https://code.visualstudio.com/sha/download?build=stable&os=win32-x64
- **File Size:** ~100 MB
- **Installation Time:** 5 minutes

---

## 📋 INSTALLATION CHECKLIST

### Phase 1: Core Tools (30 minutes)
- [ ] Download Java JDK 17
- [ ] Install Java JDK 17
- [ ] Verify Java installation
  ```powershell
  java -version
  ```

### Phase 2: Android Development (45 minutes)
- [ ] Download Android Studio
- [ ] Install Android Studio
- [ ] Open Android Studio and complete first-time setup
- [ ] Install SDK Platforms (Android 13, API 33)
- [ ] Install SDK Tools (Build-Tools 34, Emulator, Platform-Tools)
- [ ] Create Android Virtual Device (Pixel 4 or 5)

### Phase 3: Environment Configuration (15 minutes)
- [ ] Set ANDROID_HOME environment variable
- [ ] Set JAVA_HOME environment variable
- [ ] Add Android SDK tools to PATH
- [ ] **Restart Computer**

### Phase 4: Flutter Setup (15 minutes)
- [ ] Download Flutter SDK ZIP
- [ ] Extract Flutter to `C:\src\flutter`
- [ ] Add Flutter to PATH environment variable
- [ ] **Restart Computer**
- [ ] Verify Flutter: `flutter --version`
- [ ] Run: `flutter doctor`
- [ ] Accept licenses: `flutter doctor --android-licenses`

### Phase 5: Version Control (5 minutes)
- [ ] Download Git for Windows
- [ ] Install Git
- [ ] Verify Git: `git --version`

### Phase 6: IDE Setup (10 minutes)
- [ ] Install VS Code (if not already installed)
- [ ] Install Flutter extension
- [ ] Install Dart extension

### Phase 7: Backend Setup (20 minutes)
- [ ] Create Firebase account at https://console.firebase.google.com
- [ ] Create SmartShop project
- [ ] Enable Firestore Database
- [ ] Enable Realtime Database
- [ ] Enable Cloud Storage
- [ ] Create Web App and save config
- [ ] Create Android App and download google-services.json

### Phase 8: Verification (10 minutes)
- [ ] Create test Flutter project: `flutter create test_app`
- [ ] Start emulator
- [ ] Run test app: `flutter run`
- [ ] Verify app runs on emulator

---

## 🔧 ENVIRONMENT VARIABLES CHECKLIST

### Variable: ANDROID_HOME
```
Name: ANDROID_HOME
Value: C:\Users\YOUR_USERNAME\AppData\Local\Android\Sdk
```

### Variable: JAVA_HOME
```
Name: JAVA_HOME
Value: C:\Program Files\Java\jdk-17.X.X
(Replace X with your version)
```

### Variable: Path (Add These)
```
C:\Users\YOUR_USERNAME\AppData\Local\Android\Sdk\platform-tools
C:\Users\YOUR_USERNAME\AppData\Local\Android\Sdk\tools
C:\src\flutter\bin
```

---

## 💻 WINDOWS ENVIRONMENT VARIABLES TUTORIAL

### How to Open Environment Variables:
1. Press `Windows Key + X`
2. Select "System"
3. Click "Advanced system settings" on the right side
4. Click "Environment Variables" button
5. Under "User variables" click "New"

### How to Edit Path:
1. Click on "Path" in User variables
2. Click "Edit"
3. Click "New"
4. Paste the path
5. Click OK repeatedly to save

### After Adding Variables:
- **Restart your PowerShell or Command Prompt**
- Or **Restart your Computer** (more reliable)

---

## 🚀 QUICK START AFTER INSTALLATION

### Create Your Project
```powershell
cd C:\Users\YOUR_USERNAME\Documents
flutter create smart_shop_app
cd smart_shop_app
```

### Run on Emulator
```powershell
# Start emulator first
flutter emulators --launch Pixel_4_API_33

# In another terminal, run your app
flutter run
```

### Run on Physical Device
```powershell
# Connect Android phone via USB
# Enable Developer Mode (tap Build Number 7 times in Settings)
# Enable USB Debugging

flutter devices  # Should show your phone
flutter run
```

---

## 📞 COMMON ISSUES & SOLUTIONS

### Issue: "Command not found: flutter"
**Solution:** 
1. Verify Flutter path in Environment Variables
2. Restart PowerShell
3. Restart computer if still not working

### Issue: "ANDROID_HOME not found"
**Solution:**
1. Check the path in Environment Variables
2. Verify Android SDK is in that location
3. Restart computer

### Issue: "Emulator won't start"
**Solution:**
1. Open Android Studio → Device Manager
2. Click Virtual Device → Play button
3. Wait 30-60 seconds for startup
4. Check if virtualization is enabled in BIOS

### Issue: "Gradle build failed"
**Solution:**
1. Run `flutter clean`
2. Run `flutter pub get`
3. Run `flutter run`

### Issue: "Java version too old"
**Solution:**
1. Verify you installed Java 17+
2. Check JAVA_HOME points to correct version
3. Run `java -version` in new PowerShell window

---

## 📱 DEVICE SETUP FOR TESTING

### Android Emulator
- Created in Android Studio Device Manager
- No physical device needed
- Good for initial testing
- Can be slow on some computers

### Physical Android Phone
1. Connect via USB cable
2. Enable Developer Mode:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
   - Go back to Settings → Developer Options
   - Enable "USB Debugging"
3. Run `flutter devices` to verify connection
4. Run `flutter run` to start app

---

## 🎯 NEXT STEPS AFTER SETUP

1. Create Flutter project structure
2. Add Firebase dependencies
3. Initialize Firebase in app
4. Create user authentication module
5. Build product listing module
6. Implement dynamic pricing
7. Create cart system
8. Build order management

---

## 📊 ESTIMATED SYSTEM REQUIREMENTS

- **Disk Space:** 50-60 GB total (including SDKs and emulator)
- **RAM:** 8 GB minimum (16 GB recommended)
- **Internet:** Fast connection needed for initial setup
- **Time:** 2-3 hours for complete setup

---

## 📚 OFFICIAL DOCUMENTATION LINKS

- **Flutter Documentation:** https://flutter.dev/docs
- **Dart Documentation:** https://dart.dev/guides
- **Firebase Documentation:** https://firebase.google.com/docs
- **Android Documentation:** https://developer.android.com/docs
- **VS Code Documentation:** https://code.visualstudio.com/docs

---

**Last Updated:** May 6, 2026
**Status:** Ready for installation
