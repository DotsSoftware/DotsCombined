import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../api/firebase_api.dart';
import 'consultants/in_app_notification.dart';
import 'consultants/request_details.dart';
import 'firebase_options.dart';
import 'user_type.dart';
import 'utils/notification_test_page.dart';

// Global notification and navigation setup
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler (now properly defined)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');

  // Initialize local notifications for background
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create notification channel if needed
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // Show notification
  const AndroidNotificationDetails androidNotificationDetails =
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
    android: androidNotificationDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title,
    message.notification?.body,
    notificationDetails,
    payload: message.data['requestId'],
  );
}

// Check if user has an active search
Future<bool> checkActiveSearch(String userId) async {
  try {
    QuerySnapshot activeRequests = await FirebaseFirestore.instance
        .collection('notifications')
        .where('clientId', isEqualTo: userId)
        .where('status', whereIn: ['pending'])
        .orderBy('timestamp', descending: true)
        .get();
    return activeRequests.docs.isNotEmpty;
  } catch (e) {
    print('Error checking active search: $e');
    return false;
  }
}

// Initial route determination
Future<Widget> determineInitialRoute() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) return UserType();

  try {
    bool hasActiveSearch = await checkActiveSearch(user.uid);
    if (hasActiveSearch) {
      return UserType();
    }
    return UserType();
  } catch (e) {
    print('Error in determineInitialRoute: $e');
    return UserType();
  }
}

// Custom notification display function
Future<void> showCustomNotification(
  String requestId,
  String? title,
  String? body,
) async {
  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
        'in_app_channel',
        'In-App Notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'view',
            'View Details',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'decline',
            'Decline',
            showsUserInterface: true,
          ),
        ],
      );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidNotificationDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    requestId.hashCode,
    title,
    body,
    notificationDetails,
    payload: requestId,
  );
}

// In-app notification overlay
void showInAppNotification(
  BuildContext context,
  String title,
  String body,
  String requestId,
) {
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 50,
      left: 20,
      right: 20,
      child: InAppNotification(
        title: title,
        body: body,
        onView: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const RequestDetailsPage(documentId: ''),
            ),
          );
          overlayEntry.remove();
        },
        onDecline: () async {
          await declineRequest(requestId);
          overlayEntry.remove();
        },
      ),
    ),
  );

  Overlay.of(context)!.insert(overlayEntry);

  // Auto-remove after 5 seconds
  Future.delayed(Duration(seconds: 5), () {
    overlayEntry.remove();
  });
}

// Decline request handler
Future<void> declineRequest(String requestId) async {
  String? consultantId = FirebaseAuth.instance.currentUser?.uid;
  if (consultantId != null) {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(requestId)
        .update({
          'declinedBy': FieldValue.arrayUnion([consultantId]),
        });
  }
}

// Notification handling setup
Future<void> setupNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: _handleNotificationResponse,
  );

  // Create notification channels
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
  );

  const AndroidNotificationChannel inAppChannel = AndroidNotificationChannel(
    'in_app_channel',
    'In-App Notifications',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(inAppChannel);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Get FCM token
  String? fcmToken = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $fcmToken');

  // Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print('FCM Token refreshed: $newToken');
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await storeFcmTokenInFirestore(user.uid, newToken);
    }
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Received a foreground message: ${message.notification?.title}');
    _handleMessage(message);
    showCustomNotification(
      message.data['requestId'] ?? '',
      message.notification?.title,
      message.notification?.body,
    );
    showInAppNotification(
      navigatorKey.currentContext!,
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      message.data['requestId'] ?? '',
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
    _handleMessageNavigation(message);
  });
}

void _handleMessage(RemoteMessage message) {
  String? requestId = message.data['requestId'];
  if (requestId != null) {
    showInAppNotification(
      navigatorKey.currentContext!,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      requestId,
    );
  }
}

void _handleMessageNavigation(RemoteMessage message) {
  String? requestId = message.data['requestId'];
  if (requestId != null && navigatorKey.currentState != null) {
    navigatorKey.currentState?.pushNamed(
      '/request_details',
      arguments: requestId,
    );
  }
}

Future<void> _handleNotificationResponse(NotificationResponse response) async {
  if (response.payload != null) {
    if (response.actionId == 'view') {
      _handleMessageNavigation(
        RemoteMessage(data: {'requestId': response.payload!}),
      );
    } else if (response.actionId == 'decline') {
      await declineRequest(response.payload!);
    }
  }
}

// Combined FCM token storage
Future<void> storeFcmTokenInFirestore(String uid, String? fcmToken) async {
  if (fcmToken != null) {
    try {
      // Try both collections (client and consultant)
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
      print("Failed to update FCM token in one or more collections: $e");
      // Try individual updates if batch fails
      try {
        await FirebaseFirestore.instance.collection('register').doc(uid).update(
          {
            'fcmToken': fcmToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          },
        );
      } catch (e1) {
        print("Failed to update client register: $e1");
      }

      try {
        await FirebaseFirestore.instance
            .collection('consultant_register')
            .doc(uid)
            .update({
              'fcmToken': fcmToken,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
      } catch (e2) {
        print("Failed to update consultant register: $e2");
      }
    }
  }
}

// Test function to verify push notifications
Future<void> testPushNotification() async {
  try {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    print('Current FCM Token: $fcmToken');

    if (fcmToken != null) {
      // Show a test local notification
      await showCustomNotification(
        'test_request_id',
        'Welcome to Dots',
        'Notifications are working! Ensuring you never miss updates!',
      );
      print('Test notification sent successfully');
    } else {
      print('FCM token is null - notifications may not work');
    }
  } catch (e) {
    print('Error testing push notification: $e');
  }
}

// Main function
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialization
  await MobileAds.instance.initialize();
  await Future.delayed(const Duration(seconds: 3));
  FlutterNativeSplash.remove();

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Notification setup
  await setupNotifications();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseApi().initNotifications();

  // Auth state listener
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      await storeFcmTokenInFirestore(user.uid, fcmToken);

      // Test notification after user login
      await Future.delayed(Duration(seconds: 2));
      await testPushNotification();
    }
  });

  // Handle initial message
  final RemoteMessage? message = await FirebaseMessaging.instance
      .getInitialMessage();
  if (message != null) {
    print('App opened from notification: ${message.data}');
    Future.delayed(Duration(seconds: 1), () {
      _handleMessageNavigation(message);
    });
  }

  runApp(const MyApp());
}

// App widget
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          color: Colors.white,
          titleTextStyle: TextStyle(
            color: Color.fromARGB(225, 0, 74, 173),
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
          toolbarTextStyle: TextStyle(color: Color.fromARGB(225, 0, 74, 173)),
        ),
        scaffoldBackgroundColor: Colors.white,
        buttonTheme: ButtonThemeData(
          buttonColor: Color.fromARGB(225, 0, 74, 173),
          textTheme: ButtonTextTheme.primary,
        ),
      ),
      navigatorKey: navigatorKey,
      home: FutureBuilder<Widget>(
        future: determineInitialRoute(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data ?? UserType();
        },
      ),
    );
  }
}
