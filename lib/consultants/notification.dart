import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  final String requestId;

  NotificationsPage({Key? key, required this.requestId}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Stream<QuerySnapshot> _requestStream;

  @override
  void initState() {
    super.initState();
    _requestStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('requestId', isEqualTo: widget.requestId)
        .snapshots();
  }

  Future<void> _acceptRequest(String documentId) async {
    try {
      final consultantId = FirebaseAuth.instance.currentUser?.uid;
      if (consultantId == null) return;

      // Check if the request is still pending
      DocumentSnapshot requestSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(documentId)
          .get();

      if (requestSnapshot.exists &&
          requestSnapshot.data() != null &&
          (requestSnapshot.data() as Map<String, dynamic>)['status'] ==
              'pending') {
        // Update the request with consultant details
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(documentId)
            .update({
          'status': 'accepted',
          'acceptedConsultantId': consultantId,
          'acceptedTimestamp': FieldValue.serverTimestamp(),
        });

        // Fetch consultant details
        DocumentSnapshot consultantSnapshot = await FirebaseFirestore.instance
            .collection('consultant_register')
            .doc(consultantId)
            .get();

        Map<String, dynamic> consultantData =
            consultantSnapshot.data() as Map<String, dynamic>;

        // Update request with more consultant details
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(documentId)
            .update({
          'consultantName': consultantData['firstName'],
          'consultantLevel': consultantData['level'],
          'consultantIndustryType': consultantData['industry_type'],
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request accepted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'This request has already been accepted by another consultant')),
        );
      }
    } catch (e) {
      print('Error accepting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept request. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Request Details'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _requestStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data?.docs;

          if (requests == null || requests.isEmpty) {
            return Center(child: Text('Request not found'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final data = requests[index].data() as Map<String, dynamic>;
              final documentId = requests[index].id;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Industry Type: ${data['industryType'] ?? 'N/A'}',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Request Type: ${data['requestType'] ?? 'N/A'}',
                            style: TextStyle(fontSize: 18)),
                        SizedBox(height: 8),
                        Text('Status: ${data['status'] ?? 'N/A'}',
                            style: TextStyle(fontSize: 18)),
                        SizedBox(height: 16),
                        if (data['status'] == 'pending')
                          ElevatedButton(
                            onPressed: () => _acceptRequest(documentId),
                            child: Text('Accept Request'),
                          )
                        else if (data['status'] == 'accepted')
                          Text('This request has been accepted',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.green))
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
