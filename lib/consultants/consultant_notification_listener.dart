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
    if (userId == null) return;

    // Get consultant's industry type
    FirebaseFirestore.instance
        .collection('consultant_register')
        .doc(userId)
        .get()
        .then((doc) {
      if (doc.exists) {
        final industryType = doc.data()?['industry_type'] as String?;
        if (industryType == null) return;

        // Listen for new notifications matching the consultant's industry type
        _notificationSubscription?.cancel();
        _notificationSubscription = FirebaseFirestore.instance
            .collection('notifications')
            .where('industry_type', isEqualTo: industryType)
            .where('status', isEqualTo: 'searching')
            .snapshots()
            .listen((snapshot) async {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              final requestId = change.doc.id;

              // Show notification with Accept/Reject buttons
              await AppNotificationService.showNotification(
                title: '📌 New Client Request',
                body: 'New request in $industryType',
                payload: {
                  'type': 'client_request',
                  'requestId': requestId,
                  'industry': industryType,
                  'timestamp': data['timestamp']?.toDate().toString() ?? '',
                  'clientId': data['clientId'] ?? '',
                  'consultantId': userId,
                },
                actionButtons: [
                  NotificationActionButton(
                    key: 'ACCEPT',
                    label: 'Accept',
                    actionType: ActionType.Default,
                  ),
                  NotificationActionButton(
                    key: 'REJECT',
                    label: 'Reject',
                    actionType: ActionType.Default,
                  ),
                ],
              );
            }
          }
        });
      }
    });
  }

  static void stopListening() {
    _notificationSubscription?.cancel();
  }

  static Future<void> handleNotificationAction(ReceivedAction action) async {
    final payload = action.payload ?? {};
    final requestId = payload['requestId'];
    final consultantId = payload['consultantId'];

    if (requestId == null || consultantId == null) return;

    if (action.buttonKeyPressed == 'ACCEPT') {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'acceptedConsultantId': consultantId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } else if (action.buttonKeyPressed == 'REJECT') {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'rejectedBy': FieldValue.arrayUnion([consultantId]),
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    }

    // Navigate to NotificationHandlerPage
    await AppNotificationService.handleNotificationAction(payload);
  }
}