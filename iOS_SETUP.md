# iOS Setup Guide for Dots App

## Prerequisites

- macOS with Xcode 13 or later
- iOS device or simulator (iOS 12.0 or later)
- Flutter SDK installed and configured
- CocoaPods installed (`sudo gem install cocoapods`)

## Configuration Steps

### 1. iOS Configuration Files

The following files have been configured for iOS:

- **Info.plist**: Added required permissions for location, camera, photo library, microphone, and user tracking
- **AppDelegate.swift**: Configured Firebase and OneSignal initialization
- **Podfile**: Updated with proper iOS version and post-install configuration

### 2. Running the App on iOS

#### Using Xcode

1. Open the iOS project in Xcode:
   ```
   cd /Users/dotsbusiness/Documents/GitHub/DotsCombined
   open ios/Runner.xcworkspace
   ```

2. Select your target device (simulator or physical device)

3. Click the Run button or press `Cmd+R`

#### Using Flutter CLI

1. Connect your iOS device or start a simulator

2. Run the following command:
   ```
   cd /Users/dotsbusiness/Documents/GitHub/DotsCombined
   flutter run
   ```

### 3. Troubleshooting

#### Pod Installation Issues

If you encounter issues with CocoaPods, try:

```
cd ios
pod deintegrate
pod setup
pod install
```

#### Signing Issues

If you encounter signing issues:

1. Open Xcode
2. Select the Runner project
3. Go to Signing & Capabilities
4. Select your team and update the bundle identifier if needed

#### Permission Issues

Ensure all required permissions are properly configured in Info.plist:

- Location permissions
- Camera access
- Photo library access
- Microphone access
- User tracking permission

### 4. OneSignal Configuration

The OneSignal App ID has been configured in:

- AppDelegate.swift
- notification_config.dart

If you need to update the OneSignal App ID, make sure to update it in both files.

### 5. Firebase Configuration

A placeholder GoogleService-Info.plist file has been created in the Runner directory. Before deploying to production, you should replace it with the actual file from your Firebase console:

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project (dots-b3559)
3. Click on the iOS app (com.bataudev.play.dots)
4. Download the GoogleService-Info.plist file
5. Replace the placeholder file in the Runner directory with the downloaded file

## Additional Resources

- [Flutter iOS Setup Documentation](https://docs.flutter.dev/get-started/install/macos#ios-setup)
- [OneSignal Flutter Documentation](https://documentation.onesignal.com/docs/flutter-sdk-setup)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)