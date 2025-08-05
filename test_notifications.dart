// Test script for notification system
// This can be run to verify the notification implementation

import 'package:awesome_notifications/awesome_notifications.dart';

void main() async {
  // Initialize awesome notifications
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'test_channel',
        channelName: 'Test Notifications',
        channelDescription: 'Test notification channel',
        defaultColor: const Color(0xFF1E3A8A),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
      ),
    ],
    debug: true,
  );

  // Request permissions
  bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
  if (!isAllowed) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  // Send test notification
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: 1,
      channelKey: 'test_channel',
      title: 'Test Notification',
      body: 'This is a test notification to verify the system is working',
      notificationLayout: NotificationLayout.Default,
    ),
  );

  print('Test notification sent!');
}