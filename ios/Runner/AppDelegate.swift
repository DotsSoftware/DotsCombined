import Flutter
import UIKit
import Firebase
import OneSignal

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase
    FirebaseApp.configure()
    
    // Initialize OneSignal
    OneSignal.setLogLevel(.LL_VERBOSE, visualLevel: .LL_NONE)
    OneSignal.initWithLaunchOptions(launchOptions)
    OneSignal.setAppId("bc8843e0-92a5-4ce8-923f-f83470c5bba0") // OneSignal App ID from notification_config.dart
    
    // Prompt for push notifications
    OneSignal.promptForPushNotifications(userResponse: { accepted in
      print("User accepted notifications: \(accepted)")
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
