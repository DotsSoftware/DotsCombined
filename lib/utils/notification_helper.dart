/*import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Initialize notification channels
  static Future<void> initializeChannels() async {
    const AndroidNotificationChannel highImportanceChannel =
        AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
        );

    const AndroidNotificationChannel inAppChannel = AndroidNotificationChannel(
      'in_app_channel',
      'In-App Notifications',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(highImportanceChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(inAppChannel);
  }

  // Request notification permissions
  static Future<bool> requestPermissions() async {
    NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

    print('User granted permission: ${settings.authorizationStatus}');
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  // Get and store FCM token
  static Future<String?> getAndStoreFcmToken() async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      print('FCM Token: $fcmToken');

      if (fcmToken != null) {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _storeFcmTokenInFirestore(user.uid, fcmToken);
        }
      }

      return fcmToken;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // Store FCM token in Firestore
  static Future<void> _storeFcmTokenInFirestore(
    String uid,
    String fcmToken,
  ) async {
    try {
      await Future.wait([
        FirebaseFirestore.instance.collection('register').doc(uid).update({
          'fcmToken': fcmToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }),
        FirebaseFirestore.instance
            .collection('consultant_register')
            .doc(uid)
            .update({
              'fcmToken': fcmToken,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            }),
      ]);
      print('FCM token stored successfully for user: $uid');
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  // Show test notification
  static Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      999,
      'Test Notification',
      'Push notifications are working! 🎉',
      notificationDetails,
    );
  }

  // Check notification status
  static Future<void> checkNotificationStatus() async {
    try {
      // Check FCM token
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      print('FCM Token Status: ${fcmToken != null ? "Valid" : "Null"}');

      // Check permissions
      NotificationSettings settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      print('Notification Settings:');
      print('- Authorization Status: ${settings.authorizationStatus}');
      print('- Alert: ${settings.alert}');
      print('- Badge: ${settings.badge}');
      print('- Sound: ${settings.sound}');

      // Check if user is logged in
      User? user = FirebaseAuth.instance.currentUser;
      print('User Status: ${user != null ? "Logged in" : "Not logged in"}');

      if (user != null && fcmToken != null) {
        // Check if token is stored in Firestore
        try {
          DocumentSnapshot clientDoc = await FirebaseFirestore.instance
              .collection('register')
              .doc(user.uid)
              .get();

          DocumentSnapshot consultantDoc = await FirebaseFirestore.instance
              .collection('consultant_register')
              .doc(user.uid)
              .get();

          Map<String, dynamic>? clientData =
              clientDoc.data() as Map<String, dynamic>?;
          Map<String, dynamic>? consultantData =
              consultantDoc.data() as Map<String, dynamic>?;

          print(
            'Token in Client Register: ${clientDoc.exists && clientData?['fcmToken'] != null ? "Yes" : "No"}',
          );
          print(
            'Token in Consultant Register: ${consultantDoc.exists && consultantData?['fcmToken'] != null ? "Yes" : "No"}',
          );
        } catch (e) {
          print('Error checking Firestore: $e');
        }
      }
    } catch (e) {
      print('Error checking notification status: $e');
    }
  }
}
*/
