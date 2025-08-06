import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/notification_service.dart';

class ConsultantNotificationListener {
  static StreamSubscription<QuerySnapshot>? _notificationSubscription;

  static void startListening(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('No user ID found, cannot start notification listener');
      return;
    }

    print('Starting notification listener for user: $userId');

    // Get consultant's industry type
    FirebaseFirestore.instance
        .collection('consultant_register')
        .doc(userId)
        .get()
        .then((doc) {
      if (doc.exists) {
        final industryType = doc.data()?['industry_type'] as String?;
        if (industryType == null) {
          print('No industry type found for consultant: $userId');
          return;
        }

        print('Listening for notifications in industry: $industryType');

        // Listen for new notifications matching the consultant's industry type
        _notificationSubscription?.cancel();
        _notificationSubscription = FirebaseFirestore.instance
            .collection('notifications')
            .where('industry_type', isEqualTo: industryType)
            .where('status', isEqualTo: 'searching')
            .snapshots()
            .listen((snapshot) async {
          print('Received ${snapshot.docChanges.length} notification changes');
          
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              final requestId = change.doc.id;

              print('New notification received: $requestId');

              // Convert dynamic data to string payload
              final payload = AppNotificationService.convertPayload({
                'type': 'client_request',
                'requestId': requestId,
                'industry': industryType,
                'timestamp': data['timestamp']?.toDate().toString() ?? '',
                'clientId': data['clientId'] ?? '',
                'consultantId': userId,
                'jobDate': data['jobDate'] ?? '',
                'jobTime': data['jobTime'] ?? '',
                'siteLocation': data['siteLocation'] ?? '',
                'jobDescription': data['jobDescription'] ?? '',
              });

              // Show notification with Accept/Reject buttons
              await AppNotificationService.showNotification(
                title: '📌 New Client Request',
                body: 'New request in $industryType - ${data['siteLocation'] ?? 'Location not specified'}',
                payload: payload,
                channelKey: 'client_requests_channel',
                actionButtons: [
                  NotificationActionButton(
                    key: 'ACCEPT',
                    label: 'Accept',
                    actionType: ActionType.Default,
                    color: Colors.green,
                  ),
                  NotificationActionButton(
                    key: 'REJECT',
                    label: 'Reject',
                    actionType: ActionType.Default,
                    color: Colors.red,
                  ),
                ],
              );
            }
          }
        }, onError: (error) {
          print('Error in notification listener: $error');
        });
      } else {
        print('Consultant document not found for user: $userId');
      }
    }).catchError((error) {
      print('Error getting consultant data: $error');
    });
  }

  static void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    print('Notification listener stopped');
  }

  static Future<void> handleNotificationAction(ReceivedAction action) async {
    print('Handling notification action: ${action.buttonKeyPressed}');
    
    final payload = action.payload ?? {};
    final requestId = payload['requestId'];
    final consultantId = payload['consultantId'];

    if (requestId == null || consultantId == null) {
      print('Missing required payload data: requestId=$requestId, consultantId=$consultantId');
      return;
    }

    try {
      if (action.buttonKeyPressed == 'ACCEPT') {
        print('Accepting request: $requestId');
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(requestId)
            .update({
          'status': 'accepted',
          'acceptedConsultantId': consultantId,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        print('Request accepted successfully');
      } else if (action.buttonKeyPressed == 'REJECT') {
        print('Rejecting request: $requestId');
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(requestId)
            .update({
          'status': 'rejected',
          'rejectedBy': FieldValue.arrayUnion([consultantId]),
          'rejectedAt': FieldValue.serverTimestamp(),
        });
        print('Request rejected successfully');
      }

      // Navigate to NotificationHandlerPage
      await AppNotificationService.handleNotificationAction(payload);
    } catch (e) {
      print('Error handling notification action: $e');
    }
  }

  // Method to handle background notifications
  static Future<void> handleBackgroundNotification(Map<String, dynamic> data) async {
    try {
      final requestId = data['requestId'];
      final industryType = data['industry'];
      final clientId = data['clientId'];
      final consultantId = data['consultantId'];

      if (requestId != null && industryType != null) {
        // Save notification to Firestore for the consultant to see
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(requestId)
            .set({
          'clientId': clientId,
          'industry_type': industryType,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'searching',
          'jobDate': data['jobDate'] ?? '',
          'jobTime': data['jobTime'] ?? '',
          'siteLocation': data['siteLocation'] ?? '',
          'jobDescription': data['jobDescription'] ?? '',
        }, SetOptions(merge: true));

        print('Background notification saved to Firestore: $requestId');
      }
    } catch (e) {
      print('Error handling background notification: $e');
    }
  }
}