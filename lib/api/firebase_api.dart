import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Initialize notifications plugin (do this in your main.dart)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  try {
    // 1. Process the message data
    final notification = message.notification;
    final data = message.data;
    
    print('Handling background message: ${message.messageId}');
    print('Title: ${notification?.title}');
    print('Body: ${notification?.body}');
    print('Payload: $data');

    // 2. Ensure the app has initialized (important for background execution)
    WidgetsFlutterBinding.ensureInitialized();

    // 3. Initialize local notifications if not already done
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final InitializationSettings initializationSettings = 
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: DarwinInitializationSettings(),
        );
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap if needed
      },
    );

    // 4. Show local notification
    if (notification != null) {
      await _showLocalNotification(
        id: message.hashCode,
        title: notification.title ?? 'New Notification',
        body: notification.body ?? '',
        payload: data,
      );
    }

    // 5. Process any important data
    if (data.isNotEmpty) {
      await _processBackgroundData(data);
    }
  } catch (e) {
    print('Error in background message handler: $e');
    // Consider logging this error to your analytics/crash reporting
  }
}

Future<void> _showLocalNotification({
  required int id,
  required String title,
  required String body,
  required Map<String, dynamic> payload,
}) async {
  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
    'your_channel_id',
    'Your Channel Name',
    channelDescription: 'Your Channel Description',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidNotificationDetails,
    iOS: DarwinNotificationDetails(),
  );

  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    notificationDetails,
    payload: jsonEncode(payload),
  );
}

Future<void> _processBackgroundData(Map<String, dynamic> data) async {
  try {
    print('Processing background data: $data');
    
    // Example: Handle different message types
    switch (data['type']) {
      case 'chat':
        // Process chat message
        break;
      case 'request':
        // Process request update
        break;
      default:
        // Handle other message types
        break;
    }
    
    // You might want to:
    // - Update local database
    // - Schedule tasks
    // - Trigger other background processes
  } catch (e) {
    print('Error processing background data: $e');
  }
}