import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../api/firebase_api.dart';
import 'clients/login_register_page.dart';
import 'clients/search.dart';
import 'consultants/in_app_notification.dart';
import 'firebase_options.dart';
import 'user_type.dart';

// Global notification and navigation setup
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler (now properly defined)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
  
  // Create notification channel if needed
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
  );

  // Show notification
  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidNotificationDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
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
      return SearchPage(requestType: '', industryType: '');
    }
    return UserType();
  } catch (e) {
    print('Error in determineInitialRoute: $e');
    return UserType();
  }
}

// Custom notification display function
Future<void> showCustomNotification(
    String requestId, String? title, String? body) async {
  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
    'in_app_channel',
    'In-App Notifications',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    playSound: true,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction('view', 'View Details',
          showsUserInterface: true, cancelNotification: true),
      AndroidNotificationAction('decline', 'Decline', showsUserInterface: true),
    ],
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidNotificationDetails);

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
    BuildContext context, String title, String body, String requestId) {
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
          Navigator.of(context)
              .pushNamed('/request_details', arguments: requestId);
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

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _handleMessage(message);
    showCustomNotification(
      message.data['requestId'] ?? '',
      message.notification?.title,
      message.notification?.body,
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
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
      _handleMessageNavigation(RemoteMessage(
        data: {'requestId': response.payload!},
      ));
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
        }),
        FirebaseFirestore.instance.collection('consultant_register').doc(uid).update({
          'fcmToken': fcmToken,
        }),
      ]);
    } catch (e) {
      print("Failed to update FCM token in one or more collections: $e");
    }
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

  // Auth state listener
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      await storeFcmTokenInFirestore(user.uid, fcmToken);
    }
  });

  // Handle initial message
  final RemoteMessage? message = await FirebaseMessaging.instance.getInitialMessage();
  if (message != null) {
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
          toolbarTextStyle: TextStyle(
            color: Color.fromARGB(225, 0, 74, 173),
          ),
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