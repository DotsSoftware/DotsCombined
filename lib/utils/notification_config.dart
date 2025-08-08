// Notification Configuration
// Update these values according to your setup

class NotificationConfig {
  // OneSignal Configuration
  static const String oneSignalAppId = 'bc8843e0-92a5-4ce8-923f-f83470c5bba0'; // Replace with your actual OneSignal App ID
  static const String oneSignalApiKey = 'os_v2_app_xseehyesuvgorer77a2hbrn3uahuvytcxvlu5oe6wvlnmybfzm5dvfvhqm7frg4dnvytdw523zzrgux4qfjv7vcjxtrm5nyccyezpyi'; // Replace with your OneSignal REST API Key
  
  // Firebase Configuration (if needed for reference)
  static const String firebaseProjectId = 'dots-b3559'; // Your Firebase project ID
  
  // Notification Channel IDs
  static const String highImportanceChannelId = 'high_importance_channel';
  static const String clientRequestsChannelId = 'client_requests_channel';
  
  // Notification Channel Names
  static const String highImportanceChannelName = 'High Importance Notifications';
  static const String clientRequestsChannelName = 'Client Requests';
  
  // Notification Colors
  static const int primaryColor = 0xFF1E3A8A; // Blue
  static const int successColor = 0xFF059669; // Green
  static const int errorColor = 0xFFDC2626; // Red
  
  // Notification Settings
  static const bool enableVibration = true;
  static const bool enableSound = true;
  static const bool enableLights = true;
  static const bool wakeUpScreen = true;
  static const bool criticalAlert = true;
  
  // Test Configuration
  static const bool enableDebugLogs = true;
  static const bool enableTestNotifications = true;
  
  // Timeout Settings
  static const int notificationTimeoutSeconds = 300; // 5 minutes
  static const int retryAttempts = 3;
  static const int retryDelaySeconds = 5;
  
  // Validation
  static bool get isOneSignalConfigured => oneSignalAppId.isNotEmpty && oneSignalApiKey.isNotEmpty;
  
  static String get validationMessage {
    if (!isOneSignalConfigured) {
      return '⚠️ OneSignal App ID not configured. Please update NotificationConfig.oneSignalAppId';
    }
    return '✅ Notification configuration is valid';
  }
}