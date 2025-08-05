import 'package:dots/utils/notification_handler_page.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'api/firebase_api.dart';
import 'firebase_options.dart';
import 'user_type.dart';
import 'utils/notification_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppNotificationService.initialize();

  // Convert Map<String, dynamic> to Map<String, String>
  final payload = message.data.map(
    (key, value) => MapEntry(key, value?.toString() ?? ''),
  );

  await AppNotificationService.showNotification(
    title: message.notification?.title ?? 'New Request',
    body: message.notification?.body ?? 'You have a new request',
    payload: payload,
  );

  if (message.data['requestId'] != null) {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(message.data['requestId'])
        .set({
          'status': 'delivered',
          'deliveryTime': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();
  FlutterNativeSplash.preserve(
    widgetsBinding: WidgetsFlutterBinding.ensureInitialized(),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppNotificationService.initialize();
  await setupNotifications();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseApi().initNotifications();

  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      await storeFcmTokenInFirestore(user.uid, fcmToken);
    }
  });

  FlutterNativeSplash.remove();
  runApp(const MyApp());
}

Future<void> setupNotifications() async {
  // Note: flutter_local_notifications may be redundant if using awesome_notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Convert Map<String, dynamic> to Map<String, String>
    final payload = message.data.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );

    AppNotificationService.showNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
      payload: payload,
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    // Convert Map<String, dynamic> to Map<String, String>
    final payload = message.data.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );

    // Directly call handleNotificationAction with the payload
    AppNotificationService.handleNotificationAction(payload);
  });
}

Future<void> storeFcmTokenInFirestore(String uid, String? fcmToken) async {
  if (fcmToken == null) return;

  try {
    await Future.wait([
      FirebaseFirestore.instance.collection('register').doc(uid).set({
        'fcmToken': fcmToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      FirebaseFirestore.instance.collection('consultant_register').doc(uid).set(
        {'fcmToken': fcmToken, 'lastTokenUpdate': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      ),
    ]);
  } catch (e) {
    print('Error storing FCM token: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          color: Colors.white,
          titleTextStyle: TextStyle(
            color: Color.fromARGB(225, 0, 74, 173),
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: FutureBuilder<Widget>(
        future: determineInitialRoute(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data ?? const UserType();
        },
      ),
    );
  }
}

Future<Widget> determineInitialRoute() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) return const UserType();

  try {
    final activeRequest = await FirebaseFirestore.instance
        .collection('notifications')
        .where('clientId', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'searching'])
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (activeRequest.docs.isNotEmpty) {
      return NotificationHandlerPage(
        payload: {'requestId': activeRequest.docs.first.id},
      );
    }
  } catch (e) {
    print('Error determining initial route: $e');
  }

  return const UserType();
}
