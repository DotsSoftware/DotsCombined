import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_service.dart';
import 'notification_handler_page.dart';
import 'notification_config.dart';

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  static bool _debugEnabled = true;

  // OneSignal App ID from configuration
  static String get _oneSignalAppId => NotificationConfig.oneSignalAppId;

  // OneSignal REST API Key (add this to NotificationConfig)
  static String get _oneSignalApiKey => NotificationConfig.oneSignalApiKey;

  static Future<void> initialize() async {
    try {
      if (!NotificationConfig.isOneSignalConfigured) {
        print(
          '⚠️ OneSignal App ID not configured. Please update NotificationConfig.oneSignalAppId',
        );
        return;
      }

      OneSignal.initialize(_oneSignalAppId);
      await OneSignal.Notifications.requestPermission(true);
      OneSignal.Notifications.addClickListener(_onNotificationClicked);
      OneSignal.Notifications.addForegroundWillDisplayListener(
        _onForegroundNotificationReceived,
      );
      _setupUserSubscription();

      print('✅ OneSignal initialized successfully');
    } catch (e) {
      print('❌ Error initializing OneSignal: $e');
    }
  }

  static void _setupUserSubscription() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        await OneSignal.login(user.uid);
        await _storeOneSignalPlayerId(user.uid);
        print('✅ OneSignal user ID set: ${user.uid}');
      } else {
        await OneSignal.logout();
        print('✅ OneSignal user logged out');
      }
    });
  }

  static Future<void> _storeOneSignalPlayerId(String userId) async {
    try {
      String? playerId = await OneSignal.User.pushSubscription.id;

      if (_debugEnabled) {
        print('ℹ️ [OneSignal] Storing PlayerID for user: $userId');
        print('ℹ️ [OneSignal] PlayerID: $playerId');
      }

      if (playerId != null && playerId.isNotEmpty) {
        final updateData = {
          'oneSignalPlayerId': playerId,
          'lastOneSignalUpdate': FieldValue.serverTimestamp(),
          'notificationEnabled': true,
        };

        final batch = FirebaseFirestore.instance.batch();

        final userRef = FirebaseFirestore.instance
            .collection('register')
            .doc(userId);
        batch.set(userRef, updateData, SetOptions(merge: true));

        final consultantRef = FirebaseFirestore.instance
            .collection('consultant_register')
            .doc(userId);
        batch.set(consultantRef, updateData, SetOptions(merge: true));

        await batch.commit();

        if (_debugEnabled) {
          print('✅ [OneSignal] Player ID stored successfully');
        }
      } else {
        if (_debugEnabled) {
          print('⚠️ [OneSignal] No PlayerID available for user: $userId');
        }
      }
    } catch (e) {
      print('❌ [OneSignal] Error storing Player ID: $e');
      if (_debugEnabled) {
        print('Stack trace: ${e.toString()}');
      }
    }
  }

  static void _onNotificationClicked(OSNotificationClickEvent event) {
    print('🔔 OneSignal notification clicked: ${event.notification.title}');
    try {
      final payload = event.notification.additionalData;
      if (payload != null) {
        final notificationPayload = payload.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) =>
                  NotificationHandlerPage(payload: notificationPayload),
            ),
          );
        });
      }
    } catch (e) {
      print('❌ Error handling OneSignal notification click: $e');
    }
  }

  static void _onForegroundNotificationReceived(
    OSNotificationWillDisplayEvent event,
  ) {
    print(
      '🔔 OneSignal foreground notification received: ${event.notification.title}',
    );
    event.notification.display();
  }

  // Send notification to specific users via OneSignal REST API
  static Future<void> sendNotificationToUsers({
    required List<String> playerIds,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? imageUrl,
  }) async {
    try {
      if (playerIds.isEmpty) {
        print('⚠️ No player IDs provided for notification');
        return;
      }

      final notification = {
        'app_id': _oneSignalAppId,
        'include_player_ids': playerIds,
        'headings': {'en': title},
        'contents': {'en': body},
        'data': data,
        if (imageUrl != null) 'big_picture': imageUrl,
        'android_channel_id': 'high_importance_channel',
        'android_sound': 'default',
        'ios_sound': 'default',
      };

      final response = await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_oneSignalApiKey',
        },
        body: jsonEncode(notification),
      );

      if (response.statusCode == 200) {
        print(
          '✅ OneSignal notification sent successfully to ${playerIds.length} users',
        );
      } else {
        print(
          '❌ Failed to send OneSignal notification: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error sending OneSignal notification: $e');
    }
  }

  // Send notification to all users in a specific industry
  static Future<void> sendNotificationToIndustry({
    required String industryType,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? imageUrl,
  }) async {
    try {
      if (_debugEnabled) {
        print(
          'ℹ️ [OneSignal] Querying consultants for industry: $industryType',
        );
      }

      QuerySnapshot consultantSnapshot = await FirebaseFirestore.instance
          .collection('consultant_register')
          .where('industry_type', isEqualTo: industryType)
          .where('applicationStatus', isEqualTo: 'verified')
          .where('notificationEnabled', isEqualTo: true)
          .get();

      List<String> playerIds = [];
      List<String> consultantIds = [];

      for (var consultant in consultantSnapshot.docs) {
        final consultantData = consultant.data() as Map<String, dynamic>;
        String? playerId = consultantData['oneSignalPlayerId'] as String?;
        if (playerId != null && playerId.isNotEmpty) {
          playerIds.add(playerId);
          consultantIds.add(consultant.id);
        }
      }

      if (_debugEnabled) {
        print(
          'ℹ️ [OneSignal] Found ${consultantSnapshot.docs.length} consultants',
        );
        print('ℹ️ [OneSignal] Found ${playerIds.length} with PlayerIDs');
        if (playerIds.isNotEmpty) {
          print('ℹ️ [OneSignal] First PlayerID: ${playerIds.first}');
        }
      }

      if (playerIds.isNotEmpty) {
        await sendNotificationToUsers(
          playerIds: playerIds,
          title: title,
          body: body,
          data: data,
          imageUrl: imageUrl,
        );

        // Store notification log
        await _logNotificationSent(
          industryType,
          playerIds.length,
          consultantIds,
        );
      } else {
        print(
          '⚠️ [OneSignal] No valid PlayerIDs found for industry: $industryType',
        );
        // Consider falling back to FCM here
      }
    } catch (e) {
      print('❌ [OneSignal] Error in sendNotificationToIndustry: $e');
      if (_debugEnabled) {
        print('Stack trace: ${e.toString()}');
      }
    }
  }

  static Future<void> _logNotificationSent(
    String industryType,
    int recipientCount,
    List<String> consultantIds,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('notification_logs').add({
        'type': 'industry_broadcast',
        'industry': industryType,
        'recipient_count': recipientCount,
        'consultant_ids': consultantIds,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ Failed to log notification: $e');
    }
  }

  // Send client request notification via OneSignal
  static Future<void> sendClientRequestNotification({
    required String requestId,
    required String industryType,
    required String clientId,
    required String jobDate,
    required String jobTime,
    required String siteLocation,
    required String jobDescription,
  }) async {
    try {
      // Get all consultants in the specified industry
      QuerySnapshot consultantSnapshot = await FirebaseFirestore.instance
          .collection('consultant_register')
          .where('industry_type', isEqualTo: industryType)
          .where('applicationStatus', isEqualTo: 'verified')
          .get();

      if (consultantSnapshot.docs.isEmpty) {
        print('⚠️ No consultants found for industry: $industryType');
        return;
      }

      List<String> playerIds = [];
      List<String> consultantIds = [];

      // Collect all consultant player IDs
      for (var doc in consultantSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? playerId = data['oneSignalPlayerId'];
        if (playerId != null && playerId.isNotEmpty) {
          playerIds.add(playerId);
          consultantIds.add(doc.id);
        } else {
          print('⚠️ No OneSignal Player ID for consultant: ${doc.id}');
        }
      }

      if (playerIds.isEmpty) {
        print('⚠️ No valid player IDs found for industry: $industryType');
        return;
      }

      final notificationData = {
        'type': 'client_request',
        'requestId': requestId,
        'industry': industryType,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'clientId': clientId,
        'jobDate': jobDate,
        'jobTime': jobTime,
        'siteLocation': siteLocation,
        'jobDescription': jobDescription,
      };

      // Send to all collected player IDs
      await sendNotificationToUsers(
        playerIds: playerIds,
        title: '📌 New Client Request',
        body: 'New request in $industryType - $siteLocation',
        data: notificationData,
      );

      // Log successful notification
      await _logNotificationSent(industryType, playerIds.length, consultantIds);

      print(
        '✅ OneSignal client request notification sent to ${playerIds.length} consultants for industry: $industryType',
      );
    } catch (e) {
      print('❌ Error sending OneSignal client request notification: $e');
    }
  }

  // Send notification to specific consultant
  static Future<void> sendNotificationToConsultant({
    required String consultantId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? imageUrl,
  }) async {
    try {
      DocumentSnapshot consultantDoc = await FirebaseFirestore.instance
          .collection('consultant_register')
          .doc(consultantId)
          .get();

      if (consultantDoc.exists) {
        final data = consultantDoc.data() as Map<String, dynamic>?;
        String? playerId = data?['oneSignalPlayerId'] as String?;
        if (playerId != null && playerId.isNotEmpty) {
          await sendNotificationToUsers(
            playerIds: [playerId],
            title: title,
            body: body,
            data: data ?? {},
            imageUrl: imageUrl,
          );
        } else {
          print(
            '⚠️ No OneSignal Player ID found for consultant: $consultantId',
          );
        }
      } else {
        print('⚠️ Consultant document not found: $consultantId');
      }
    } catch (e) {
      print('❌ Error sending OneSignal notification to consultant: $e');
    }
  }

  // Test OneSignal notification system
  static Future<void> testOneSignalSystem() async {
    try {
      print('🧪 Testing OneSignal notification system...');

      String? currentPlayerId = await OneSignal.User.pushSubscription.id;
      if (currentPlayerId != null) {
        await sendNotificationToUsers(
          playerIds: [currentPlayerId],
          title: 'OneSignal Test',
          body: 'OneSignal notification system is working! 🎉',
          data: {'test': 'onesignal_success'},
        );
        print('✅ OneSignal test notification sent to current user');
      } else {
        print('⚠️ No OneSignal Player ID available for current user');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot consultantDoc = await FirebaseFirestore.instance
            .collection('consultant_register')
            .doc(user.uid)
            .get();

        if (consultantDoc.exists) {
          final data = consultantDoc.data() as Map<String, dynamic>?;
          String industryType = data?['industry_type'] as String? ?? '';
          if (industryType.isNotEmpty) {
            await sendNotificationToIndustry(
              industryType: industryType,
              title: 'OneSignal Industry Test',
              body:
                  'Testing OneSignal notifications for $industryType industry',
              data: {'test': 'onesignal_industry_test'},
            );
            print('✅ OneSignal industry test notification sent');
          }
        }
      }
    } catch (e) {
      print('❌ Error testing OneSignal system: $e');
    }
  }

  static Future<String?> getCurrentPlayerId() async {
    try {
      return await OneSignal.User.pushSubscription.id;
    } catch (e) {
      print('❌ Error getting OneSignal Player ID: $e');
      return null;
    }
  }

  static Future<bool> isSubscribed() async {
    try {
      return await OneSignal.User.pushSubscription.optedIn ?? false;
    } catch (e) {
      print('❌ Error checking OneSignal subscription: $e');
      return false;
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      bool granted = await OneSignal.Notifications.requestPermission(true);
      print('✅ OneSignal permissions granted: $granted');
      return granted;
    } catch (e) {
      print('❌ Error requesting OneSignal permissions: $e');
      return false;
    }
  }
}
