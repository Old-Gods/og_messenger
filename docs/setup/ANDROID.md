# Android Setup & Release Build Guide

This guide covers setting up OG Messenger for Android development and creating release builds for Google Play Store distribution.

## Prerequisites

- Flutter SDK installed and configured
- Android Studio or Android SDK command-line tools
- Java Development Kit (JDK) 17 or higher

## Development Setup

### 1. Configure Android SDK

Ensure your Android SDK is properly configured:

```bash
flutter doctor
```

### 2. Multicast Support

OG Messenger requires multicast networking for peer discovery. The app automatically acquires a multicast lock on Android via a platform channel implementation.

**No additional setup required** - the multicast lock is handled automatically when the app starts.

## Release Build Configuration

### 1. Generate Upload Keystore

**IMPORTANT**: If you lose your keystore, you will **never** be able to update your app on Google Play. Back it up securely!

Generate a new upload keystore (one-time setup):

```bash
keytool -genkey -v -keystore ~/.google-play/upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD
```

**Important notes**:
- Use a strong password for both `-storepass` and `-keypass`
- Store these passwords securely (password manager recommended)
- Keep the `.jks` file backed up in a secure location
- The `-validity 10000` sets the key validity to ~27 years

### 2. Configure key.properties

Create `android/key.properties` with your keystore credentials:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/path/to/your/upload-keystore.jks
```

**Security notes**:
- This file is already in `.gitignore` - never commit it to version control
- Use absolute paths for `storeFile`
- Keep this file secure on your development machine

### 3. Build Configuration

The release build is configured in [android/app/build.gradle.kts](../../android/app/build.gradle.kts) with:

- **Signing**: Automatically loads credentials from `key.properties`
- **Code shrinking**: Enabled via R8 (reduces APK size)
- **Obfuscation**: Enabled to protect code from reverse engineering
- **ProGuard rules**: Configured in [android/app/proguard-rules.pro](../../android/app/proguard-rules.pro) to preserve Flutter framework

**Application ID**: `com.oldgods.ogmessenger`

## Building for Release

### Build App Bundle (Google Play)

Google Play requires the Android App Bundle (`.aab`) format:

```bash
flutter build appbundle --release
```

The signed `.aab` file will be located at:
```
build/app/outputs/bundle/release/app-release.aab
```

### Build APK (Direct Distribution)

To build a signed APK for direct distribution:

```bash
flutter build apk --release
```

The signed APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Split APKs by Architecture

To generate separate APKs for each CPU architecture (smaller file sizes):

```bash
flutter build apk --release --split-per-abi
```

This generates:
- `app-arm64-v8a-release.apk` (64-bit ARM - most modern devices)
- `app-armeabi-v7a-release.apk` (32-bit ARM - older devices)
- `app-x86_64-release.apk` (64-bit x86 - emulators/tablets)

## Version Management

App version is managed in [pubspec.yaml](../../pubspec.yaml):

```yaml
version: 2.0.0+2
```

Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`

- **Version name**: `2.0.0` (displayed to users)
- **Version code**: `2` (must increment for each Play Store upload)

To update:
1. Edit `pubspec.yaml`
2. Increment both version name and build number
3. Rebuild the app

## Google Play Console Setup

### First-Time App Upload

1. **Create app listing** in Google Play Console
2. **Upload the `.aab` file** (not the `.apk`)
3. **Configure store listing** (screenshots, description, etc.)
4. **Complete content rating questionnaire**
5. **Set pricing & distribution** (free/paid, countries)
6. **Submit for review**

### App Updates

For subsequent updates:
1. Increment version in `pubspec.yaml`
2. Build new app bundle: `flutter build appbundle --release`
3. Upload to Play Console (Production or Testing track)
4. Write release notes
5. Submit for review

## Testing Release Builds

### Local Testing

Test the release build on a physical device:

```bash
flutter install --release
```

Or manually install the APK:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Internal Testing Track

Use Google Play Console's Internal Testing track to test the `.aab` before public release:
1. Upload to Internal Testing
2. Add test user email addresses
3. Share the testing link with your team

## Troubleshooting

### Build Fails: "keystore not found"

**Solution**: Check that the `storeFile` path in `android/key.properties` is correct and uses an absolute path.

### Build Fails: "signing config not found"

**Solution**: Ensure `android/key.properties` exists and contains all four required properties.

### App Crashes on Release but Not Debug

**Solution**: ProGuard/R8 may be removing necessary code. Add keep rules to `android/app/proguard-rules.pro`:

```proguard
-keep class com.yourpackage.** { *; }
```

### Multicast Not Working

**Solution**: Ensure the app has these permissions in `AndroidManifest.xml`:
- `android.permission.INTERNET`
- `android.permission.ACCESS_WIFI_STATE`
- `android.permission.CHANGE_WIFI_MULTICAST_STATE`

These are already configured in the app.

## Security Best Practices

1. **Never commit keystore files** - Already in `.gitignore`
2. **Never commit key.properties** - Already in `.gitignore`
3. **Use strong passwords** - At least 16 characters
4. **Back up your keystore** - Store in multiple secure locations
5. **Use Play App Signing** - Enable in Play Console (recommended)

## Performance Optimization

Release builds include:
- **R8 code shrinking** - Removes unused code
- **Obfuscation** - Makes reverse engineering harder
- **Resource shrinking** - Removes unused resources
- **Compilation optimizations** - AOT compilation for best performance

## CI/CD Integration

For automated builds (GitHub Actions, etc.):

1. Store keystore in CI/CD secrets (base64 encoded)
2. Store passwords in CI/CD secrets
3. Generate `key.properties` during build
4. Build and upload to Play Console API

Example GitHub Actions workflow snippet:

```yaml
- name: Configure keystore
  env:
    KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
    STORE_PASSWORD: ${{ secrets.STORE_PASSWORD }}
    KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
  run: |
    echo "$KEYSTORE_BASE64" | base64 --decode > android/app/upload-keystore.jks
    echo "storePassword=$STORE_PASSWORD" > android/key.properties
    echo "keyPassword=$KEY_PASSWORD" >> android/key.properties
    echo "keyAlias=upload" >> android/key.properties
    echo "storeFile=upload-keystore.jks" >> android/key.properties

- name: Build app bundle
  run: flutter build appbundle --release
```

## Additional Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Android App Bundle Format](https://developer.android.com/guide/app-bundle)
- [ProGuard Rules](https://developer.android.com/studio/build/shrink-code)

## Platform-Specific Notes

### Network ID & Multicast

OG Messenger uses a **network ID** to isolate groups of users on the same LAN. The network ID is displayed in Settings after the first user is authenticated.

**All users must be on the same WiFi network AND use the same network ID** to communicate.

### Background Behavior

On Android 12+ (API 31), background limitations may affect message delivery when the app is in the background. The app uses:
- Wake locks to keep networking active
- Foreground service (when implemented) for persistent connections
- Local notifications for incoming messages

## Support

For issues specific to Android builds, check:
- [Project TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- [GitHub Issues](https://github.com/Old-Gods/og_messenger/issues)
- [Flutter Android build documentation](https://docs.flutter.dev/deployment/android)
