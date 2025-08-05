import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dots/consultants/consultant_notification_listener.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'notification_handler_page.dart';

// Update typedef to allow nullable strings
typedef NotificationPayload = Map<String, String?>;

class AppNotificationService {
  static final AppNotificationService _instance = AppNotificationService._internal();
  factory AppNotificationService() => _instance;
  AppNotificationService._internal();

  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null,
      [
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
      ],
      debug: true,
    );

    await _requestNotificationPermissions();
    await _configureNotificationActions();
  }

  static Future<void> _requestNotificationPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static Future<void> _configureNotificationActions() async {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: ConsultantNotificationListener.handleNotificationAction,
    );
  }

  static Future<void> handleNotificationAction(NotificationPayload payload) async {
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
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch % 10000,
        channelKey: channelKey ?? 'high_importance_channel',
        title: title,
        body: body,
        payload: payload,
        notificationLayout: NotificationLayout.Default,
        criticalAlert: true,
      ),
      actionButtons: actionButtons,
    );
  }

  static Future<void> testNotificationSystem() async {
    await showNotification(
      title: 'Test Notification',
      body: 'Notification system is working',
      payload: {'test': 'success'},
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();



