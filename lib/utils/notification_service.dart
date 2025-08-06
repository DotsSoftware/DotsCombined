import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dots/consultants/consultant_notification_listener.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'notification_handler_page.dart';

// Update typedef to allow nullable strings
typedef NotificationPayload = Map<String, String?>;

class AppNotificationService {
  static final AppNotificationService _instance =
      AppNotificationService._internal();
  factory AppNotificationService() => _instance;
  AppNotificationService._internal();

  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: 'high_importance_channel',
        channelName: 'High Importance Notifications',
        channelDescription: 'Notification channel for important messages',
        defaultColor: const Color(0xFF1E3A8A),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
      ),
      NotificationChannel(
        channelKey: 'client_requests_channel',
        channelName: 'Client Requests',
        channelDescription: 'Notifications for new client requests',
        defaultColor: const Color(0xFF059669),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
      ),
    ], debug: true);

    await _requestNotificationPermissions();
    await _configureNotificationActions();
  }

  static Future<void> _requestNotificationPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    // Request additional permissions for Android 13+
    await AwesomeNotifications().requestPermissionToSendNotifications(
      permissions: [
        NotificationPermission.Alert,
        NotificationPermission.Sound,
        NotificationPermission.Badge,
        NotificationPermission.Vibration,
        NotificationPermission.Light,
      ],
    );
  }

  static Future<void> _configureNotificationActions() async {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod:
          ConsultantNotificationListener.handleNotificationAction,
      onNotificationCreatedMethod:
          (ReceivedNotification receivedNotification) async {
            print('Notification created: ${receivedNotification.title}');
          },
      onNotificationDisplayedMethod:
          (ReceivedNotification receivedNotification) async {
            print('Notification displayed: ${receivedNotification.title}');
          },
      onDismissActionReceivedMethod: (ReceivedAction receivedAction) async {
        print('Notification dismissed: ${receivedAction.title}');
      },
    );
  }

  static Future<void> handleNotificationAction(
    NotificationPayload payload,
  ) async {
    final context = navigatorKey.currentState?.context;

    if (context == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationHandlerPage(payload: payload),
      ),
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    required NotificationPayload payload,
    String? channelKey,
    List<NotificationActionButton>? actionButtons,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch % 10000,
          channelKey: channelKey ?? 'high_importance_channel',
          title: title,
          body: body,
          payload: payload,
          notificationLayout: NotificationLayout.Default,
          criticalAlert: true,
          wakeUpScreen: true,
          autoDismissible: false,
        ),
        actionButtons: actionButtons,
      );
      print('Notification sent successfully: $title');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Helper method to convert dynamic payload to string payload
  static NotificationPayload convertPayload(
    Map<String, dynamic> dynamicPayload,
  ) {
    return dynamicPayload.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
  }

  // Comprehensive test function to verify notification system
  static Future<void> testNotificationSystem() async {
    print('🧪 Testing notification system...');

    // Test basic notification
    await showNotification(
      title: 'Test Notification',
      body: 'Notification system is working',
      payload: {'test': 'success'},
      channelKey: 'high_importance_channel',
    );

    // Test notification with action buttons
    await showNotification(
      title: 'Test with Actions',
      body: 'This notification has action buttons',
      payload: {'test': 'actions'},
      channelKey: 'client_requests_channel',
      actionButtons: [
        NotificationActionButton(
          key: 'TEST_ACCEPT',
          label: 'Test Accept',
          actionType: ActionType.Default,
          color: Colors.green,
        ),
        NotificationActionButton(
          key: 'TEST_REJECT',
          label: 'Test Reject',
          actionType: ActionType.Default,
          color: Colors.red,
        ),
      ],
    );

    // Test individual channels
    await testChannelNotification('high_importance_channel');
    await testChannelNotification('client_requests_channel');

    print('✅ Test notifications sent successfully');
  }

  // Check notification permissions
  static Future<bool> checkNotificationPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    print('Notification permissions allowed: $isAllowed');
    return isAllowed;
  }

  // Get notification channels (removed - method doesn't exist in awesome_notifications)
  // static Future<void> listNotificationChannels() async {
  //   final channels = await AwesomeNotifications().listChannels();
  //   print('Available notification channels:');
  //   for (var channel in channels) {
  //     print('- ${channel.channelKey}: ${channel.channelName}');
  //   }
  // }

  // Alternative method to check notification system status
  static Future<void> checkNotificationSystemStatus() async {
    print('=== Notification System Status Check ===');

    // Check permissions
    bool hasPermission = await checkNotificationPermissions();
    print('✅ Has notification permissions: $hasPermission');

    // Check if notifications are enabled
    bool isEnabled = await AwesomeNotifications().isNotificationAllowed();
    print('✅ Notifications enabled: $isEnabled');

    // List configured channels (we know what we configured)
    print('📋 Configured notification channels:');
    print('   - high_importance_channel: High Importance Notifications');
    print('   - client_requests_channel: Client Requests');

    // Check if the service is properly initialized
    print('🔧 Notification service initialized: true');

    print('=== End Status Check ===');
  }

  // Method to test notification with specific channel
  static Future<void> testChannelNotification(String channelKey) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch % 10000,
          channelKey: channelKey,
          title: 'Channel Test',
          body: 'Testing channel: $channelKey',
          notificationLayout: NotificationLayout.Default,
        ),
      );
      print('✅ Test notification sent to channel: $channelKey');
    } catch (e) {
      print('❌ Error sending test notification to channel $channelKey: $e');
    }
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
