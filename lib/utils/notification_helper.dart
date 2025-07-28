import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  // Cache for FCM token to avoid repeated API calls
  static String? _cachedFcmToken;
  static DateTime? _tokenCacheTime;
  static const Duration _tokenCacheTimeout = Duration(hours: 1);

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

  // Request notification permissions with better error handling
  static Future<bool> requestPermissions() async {
    try {
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

      print('User granted permission: ${settings.authorizationStatus}');
      
      // Also save permission status locally
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_permission_granted', 
          settings.authorizationStatus == AuthorizationStatus.authorized);
      
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  // Get and store FCM token with caching
  static Future<String?> getAndStoreFcmToken({bool forceRefresh = false}) async {
    try {
      // Check cache first unless force refresh is requested
      if (!forceRefresh && _cachedFcmToken != null && _tokenCacheTime != null) {
        if (DateTime.now().difference(_tokenCacheTime!) < _tokenCacheTimeout) {
          print('Using cached FCM token');
          return _cachedFcmToken;
        }
      }

      String? fcmToken = await FirebaseMessaging.instance.getToken();
      print('FCM Token: $fcmToken');

      if (fcmToken != null && fcmToken.isNotEmpty) {
        // Update cache
        _cachedFcmToken = fcmToken;
        _tokenCacheTime = DateTime.now();
        
        // Store in SharedPreferences for persistence
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', fcmToken);
        await prefs.setString('fcm_token_timestamp', DateTime.now().toIso8601String());

        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _storeFcmTokenInFirestore(user.uid, fcmToken);
        }
      }

      return fcmToken;
    } catch (e) {
      print('Error getting FCM token: $e');
      
      // Try to get cached token from SharedPreferences as fallback
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? cachedToken = prefs.getString('fcm_token');
        if (cachedToken != null) {
          print('Using fallback token from SharedPreferences');
          return cachedToken;
        }
      } catch (prefError) {
        print('Error accessing SharedPreferences: $prefError');
      }
      
      return null;
    }
  }

  // Store FCM token in Firestore with retry logic
  static Future<void> _storeFcmTokenInFirestore(
    String uid,
    String fcmToken,
  ) async {
    try {
      final Map<String, dynamic> tokenData = {
        'fcmToken': fcmToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'deviceInfo': {
          'platform': 'flutter',
          'updateTime': DateTime.now().toIso8601String(),
        }
      };

      // Use batched writes for better performance and consistency
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      // Try to update both collections
      DocumentReference clientRef = FirebaseFirestore.instance
          .collection('register')
          .doc(uid);
      DocumentReference consultantRef = FirebaseFirestore.instance
          .collection('consultant_register')
          .doc(uid);

      batch.set(clientRef, tokenData, SetOptions(merge: true));
      batch.set(consultantRef, tokenData, SetOptions(merge: true));

      await batch.commit();
      print('FCM token stored successfully for user: $uid');
    } catch (e) {
      print('Error storing FCM token: $e');
      // Retry individual updates if batch fails
      try {
        await _retryTokenStorage(uid, fcmToken);
      } catch (retryError) {
        print('Retry also failed: $retryError');
      }
    }
  }

  // Retry token storage with individual updates
  static Future<void> _retryTokenStorage(String uid, String fcmToken) async {
    final Map<String, dynamic> tokenData = {
      'fcmToken': fcmToken,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    };

    List<Future> updates = [];
    
    // Try client register
    updates.add(
      FirebaseFirestore.instance
          .collection('register')
          .doc(uid)
          .set(tokenData, SetOptions(merge: true))
          .catchError((e) => print('Failed to update client register: $e'))
    );

    // Try consultant register
    updates.add(
      FirebaseFirestore.instance
          .collection('consultant_register')
          .doc(uid)
          .set(tokenData, SetOptions(merge: true))
          .catchError((e) => print('Failed to update consultant register: $e'))
    );

    await Future.wait(updates);
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

  // Enhanced notification status check
  static Future<void> checkNotificationStatus() async {
    try {
      print('=== Notification Status Check ===');
      
      // Check FCM token
      String? fcmToken = await getAndStoreFcmToken();
      print('FCM Token Status: ${fcmToken != null ? "Valid" : "Null"}');
      if (fcmToken != null) {
        print('Token: ${fcmToken.substring(0, 20)}...');
      }

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
      print('User Status: ${user != null ? "Logged in (${user.uid})" : "Not logged in"}');

      if (user != null && fcmToken != null) {
        // Check if token is stored in Firestore
        await _checkTokenInFirestore(user.uid, fcmToken);
      }

      // Check SharedPreferences cache
      await _checkTokenCache();
      
      print('=== End Status Check ===');
    } catch (e) {
      print('Error checking notification status: $e');
    }
  }

  // Check token storage in Firestore
  static Future<void> _checkTokenInFirestore(String uid, String fcmToken) async {
    try {
      DocumentSnapshot clientDoc = await FirebaseFirestore.instance
          .collection('register')
          .doc(uid)
          .get();

      DocumentSnapshot consultantDoc = await FirebaseFirestore.instance
          .collection('consultant_register')
          .doc(uid)
          .get();

      Map<String, dynamic>? clientData =
          clientDoc.data() as Map<String, dynamic>?;
      Map<String, dynamic>? consultantData =
          consultantDoc.data() as Map<String, dynamic>?;

      print('Firestore Token Status:');
      print('- Client Register: ${clientDoc.exists && clientData?['fcmToken'] == fcmToken ? "✓ Valid" : "✗ Invalid/Missing"}');
      print('- Consultant Register: ${consultantDoc.exists && consultantData?['fcmToken'] == fcmToken ? "✓ Valid" : "✗ Invalid/Missing"}');
      
      if (clientDoc.exists && clientData?['fcmToken'] != fcmToken) {
        print('- Client token mismatch, updating...');
        await _storeFcmTokenInFirestore(uid, fcmToken);
      }
      
      if (consultantDoc.exists && consultantData?['fcmToken'] != fcmToken) {
        print('- Consultant token mismatch, updating...');
        await _storeFcmTokenInFirestore(uid, fcmToken);
      }
    } catch (e) {
      print('Error checking Firestore tokens: $e');
    }
  }

  // Check token cache in SharedPreferences
  static Future<void> _checkTokenCache() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedToken = prefs.getString('fcm_token');
      String? cacheTime = prefs.getString('fcm_token_timestamp');
      
      print('Local Cache Status:');
      print('- Cached Token: ${cachedToken != null ? "✓ Present" : "✗ Missing"}');
      print('- Cache Time: ${cacheTime ?? "Not set"}');
      
      if (cacheTime != null) {
        DateTime cacheDateTime = DateTime.parse(cacheTime);
        Duration age = DateTime.now().difference(cacheDateTime);
        print('- Cache Age: ${age.inMinutes} minutes');
        print('- Cache Valid: ${age < _tokenCacheTimeout ? "✓ Yes" : "✗ Expired"}');
      }
    } catch (e) {
      print('Error checking token cache: $e');
    }
  }

  // Clear token cache (useful for debugging)
  static Future<void> clearTokenCache() async {
    try {
      _cachedFcmToken = null;
      _tokenCacheTime = null;
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      await prefs.remove('fcm_token_timestamp');
      
      print('Token cache cleared');
    } catch (e) {
      print('Error clearing token cache: $e');
    }
  }
}
