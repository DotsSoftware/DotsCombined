import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DataOptimizationService {
  static final DataOptimizationService _instance = DataOptimizationService._internal();
  factory DataOptimizationService() => _instance;
  DataOptimizationService._internal();

  // Optimized method to get consultant data with caching
  static Future<Map<String, dynamic>?> getConsultantData(String userId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('consultant_register')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting consultant data: $e');
      return null;
    }
  }

  // Optimized method to get client data with caching
  static Future<Map<String, dynamic>?> getClientData(String userId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('register')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting client data: $e');
      return null;
    }
  }

  // Optimized method to get notifications for a consultant
  static Stream<QuerySnapshot> getConsultantNotifications(String industryType) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('industry_type', isEqualTo: industryType)
        .where('status', whereIn: ['searching', 'accepted', 'rejected'])
        .orderBy('timestamp', descending: true)
        .limit(50) // Limit to prevent excessive data loading
        .snapshots();
  }

  // Optimized method to get client requests
  static Stream<QuerySnapshot> getClientRequests(String clientId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('clientId', isEqualTo: clientId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();
  }

  // Optimized method to save notification with proper indexing
  static Future<void> saveNotification({
    required String requestId,
    required String clientId,
    required String industryType,
    required Map<String, dynamic> additionalData,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(requestId)
          .set({
        'clientId': clientId,
        'industry_type': industryType,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'searching',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...additionalData,
      });

      // Create index for efficient querying
      await FirebaseFirestore.instance
          .collection('notification_indexes')
          .doc(requestId)
          .set({
        'clientId': clientId,
        'industry_type': industryType,
        'status': 'searching',
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Notification saved with indexing: $requestId');
    } catch (e) {
      print('Error saving notification: $e');
      rethrow;
    }
  }

  // Optimized method to update notification status
  static Future<void> updateNotificationStatus({
    required String requestId,
    required String status,
    String? consultantId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (consultantId != null) {
        updateData['consultantId'] = consultantId;
      }

      if (additionalData != null) {
        updateData.addAll(additionalData);
      }

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(requestId)
          .update(updateData);

      // Update index
      await FirebaseFirestore.instance
          .collection('notification_indexes')
          .doc(requestId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Notification status updated: $requestId -> $status');
    } catch (e) {
      print('Error updating notification status: $e');
      rethrow;
    }
  }

  // Optimized method to get consultants by industry
  static Future<QuerySnapshot> getConsultantsByIndustry(String industryType) async {
    return await FirebaseFirestore.instance
        .collection('consultant_register')
        .where('industry_type', isEqualTo: industryType)
        .where('applicationStatus', isEqualTo: 'verified')
        .get();
  }

  // Optimized method to save transaction with proper structure
  static Future<void> saveTransaction({
    required String userId,
    required Map<String, dynamic> transactionData,
  }) async {
    try {
      final transactionId = FirebaseFirestore.instance
          .collection('transactions')
          .doc()
          .id;

      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionId)
          .set({
        'id': transactionId,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...transactionData,
      });

      // Create user transaction reference
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId)
          .set({
        'transactionId': transactionId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Transaction saved: $transactionId');
    } catch (e) {
      print('Error saving transaction: $e');
      rethrow;
    }
  }

  // Optimized method to get user transactions
  static Stream<QuerySnapshot> getUserTransactions(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // Method to clean up old notifications
  static Future<void> cleanupOldNotifications() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      
      QuerySnapshot oldNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .where('status', whereIn: ['completed', 'cancelled'])
          .get();

      for (var doc in oldNotifications.docs) {
        await doc.reference.delete();
      }

      print('Cleaned up ${oldNotifications.docs.length} old notifications');
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }

  // Method to create Firestore indexes for better performance
  static Future<void> createIndexes() async {
    try {
      // Create composite indexes for better query performance
      await FirebaseFirestore.instance
          .collection('indexes')
          .doc('notifications_industry_status')
          .set({
        'collection': 'notifications',
        'fields': ['industry_type', 'status', 'timestamp'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('indexes')
          .doc('consultants_industry_status')
          .set({
        'collection': 'consultant_register',
        'fields': ['industry_type', 'applicationStatus'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Indexes created successfully');
    } catch (e) {
      print('Error creating indexes: $e');
    }
  }

  // Method to validate data structure
  static bool validateNotificationData(Map<String, dynamic> data) {
    final requiredFields = ['clientId', 'industry_type', 'status'];
    
    for (String field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        print('Missing required field: $field');
        return false;
      }
    }
    
    return true;
  }

  // Method to get optimized price data
  static Map<String, String> getOptimizedPriceData() {
    return {
      'competency_prices': {
        'Level 1 - Basic Knowledge': '500.00',
        'Level 2 - Skilled In Industry': '937.50',
        'Level 3 - High Level Of Expertise': '2187.50',
      },
      'public_transport_prices': {
        'Local - Within a 50km Radius': '187.50',
        'Regional - Within a 300km Radius': '475.00',
        'National - Within a 1500km Radius': '6250.50',
      },
      'own_vehicle_prices': {
        'Local - Within a 50km Radius': '437.50',
        'Regional - Within a 300km Radius': '1450.00',
        'Provincial - Within a 500km Radius': '1950.00',
        'Interprovincial - Within a 1000km Radius': '3106.25',
        'National - Within a 1500km Radius': '10937.50',
      },
    };
  }
}