import 'package:dots/consultants/consultant_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'inbox.dart';

class JobDetailsPage extends StatefulWidget {
  final String requestId;

  const JobDetailsPage({required this.requestId, Key? key}) : super(key: key);

  @override
  _JobDetailsPageState createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _jobDetails;
  bool _isAccepted = false;
  Map<String, dynamic>? selectedConsultant;

  @override
  void initState() {
    super.initState();
    _fetchJobDetails();
  }

  Future<void> _fetchJobDetails() async {
    try {
      DocumentSnapshot jobDoc =
          await FirebaseFirestore.instance
              .collection('active_requests')
              .doc(widget.requestId)
              .get();

      if (jobDoc.exists) {
        setState(() {
          _jobDetails = jobDoc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        // Handle case where job details are not found
        setState(() {
          _jobDetails = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching job details: $e');
      setState(() {
        _isLoading = false;
      });
      // Show error message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch job details.')));
    }
  }

  Future<void> _acceptJob() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("User not logged in");
      }

      String consultantId = user.uid;

      // Update the job request document
      await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.requestId)
          .update({'status': 'accepted', 'consultantId': consultantId});

      setState(() {
        _isAccepted = true;
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Job accepted successfully!')));
    } catch (e) {
      print('Error accepting job: $e');
      setState(() {
        _isLoading = false;
      });
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept job. Please try again.')),
      );
    }
  }

  Future<void> storeConsultantDetails(
    String userId,
    Map<String, dynamic> consultantDetails,
  ) async {
    try {
      // Storing consultant details in the user's document in a collection named "selectedConsultants"

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(userId)
          .collection('selectedConsultants')
          .add(consultantDetails);

      print('Consultant details stored successfully.');
    } catch (e) {
      print('Error storing consultant details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () async {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConsultantDashboardPage(),
                ),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _jobDetails == null
              ? Center(child: Text('Job details not found'))
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Industry Type: ${_jobDetails!['industry_type'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Job Description: ${_jobDetails!['job_description'] ?? 'N/A'}',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    if (!_isAccepted)
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            _acceptJob();
                            try {
                              String userId =
                                  FirebaseAuth.instance.currentUser?.uid ?? '';
                              await storeConsultantDetails(
                                userId,
                                selectedConsultant!,
                              );
                              print('storeConsultantDetails method called');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InboxPage(),
                                ),
                              );
                            } catch (e) {
                              print('Error: $e');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: Color.fromARGB(225, 0, 74, 173),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Text(
                              'Accept Consultant',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}
