import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'inbox.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient

class RequestDetailsPage extends StatefulWidget {
  final String documentId;

  const RequestDetailsPage({Key? key, required this.documentId})
    : super(key: key);

  @override
  _RequestDetailsPageState createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage>
    with TickerProviderStateMixin {
  String industryType = 'Loading...';
  String jobDate = '';
  String jobTime = '';
  String siteLocation = '';
  String jobDescription = '';
  bool isLoading = true;
  String errorMessage = '';
  String jobStatus = '';
  List<Map<String, dynamic>> userIndustries = [];
  bool canAcceptJobs = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchUserIndustries();
    _fetchNotificationDetails();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  Future<void> _launchMaps(String address) async {
    final encodedAddress = Uri.encodeFull(address);
    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress';

    if (await canLaunch(mapsUrl)) {
      await launch(mapsUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open maps'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _fetchUserIndustries() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc = await FirebaseFirestore.instance
            .collection('consultant_register')
            .doc(currentUser.uid)
            .get();

        if (doc.exists) {
          if (doc.data()?['industries'] != null) {
            final industries = List<Map<String, dynamic>>.from(
              doc.data()?['industries'],
            );
            setState(() {
              userIndustries = industries;
              if (industryType != 'Loading...') {
                canAcceptJobs = industries.any(
                  (industry) =>
                      industry['type'].toString().toLowerCase() ==
                      industryType.toLowerCase(),
                );
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching user industries: $e');
    }
  }

  Future<void> _fetchNotificationDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.documentId)
          .get();

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          industryType = data['industry_type'] ?? 'Not specified';
          jobDate = data['jobDate'] ?? 'Not specified';
          jobTime = data['jobTime'] ?? 'Not specified';
          siteLocation = data['siteLocation'] ?? 'Not specified';
          jobDescription = data['jobDescription'] ?? 'Not specified';
          jobStatus = data['status'] ?? '';
          isLoading = false;
          canAcceptJobs = userIndustries.any(
            (industry) =>
                industry['type'].toString().toLowerCase() ==
                industryType.toLowerCase(),
          );
        });
      } else {
        setState(() {
          errorMessage = 'Notification not found';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching notification details: $e');
      setState(() {
        errorMessage = 'Failed to load notification details: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _acceptNotification() async {
    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.documentId)
          .update({
            'status': 'accepted',
            'acceptedTimestamp': FieldValue.serverTimestamp(),
            'acceptedConsultantId': FirebaseAuth.instance.currentUser?.uid,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => InboxPage()));
    } catch (e) {
      print('Error accepting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept request: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildModernCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: const Color(0xFF1E3A8A), size: 24),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: isLink ? Colors.blue : Colors.white,
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 16,
      thickness: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job Description',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          jobDescription,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(String message, Color bgColor, Color textColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor.withOpacity(0.5)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isJobAccepted = jobStatus == 'accepted';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Image.network(
                                  'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.error_outline,
                                        color: Color(0xFF1E3A8A),
                                        size: 30,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Details',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Error Message
                    if (errorMessage.isNotEmpty)
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    errorMessage,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Info Card
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildModernCard(
                          title: 'Job Information',
                          icon: Icons.work,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                Icons.business,
                                'Industry',
                                industryType,
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                Icons.calendar_today,
                                'Date',
                                jobDate,
                              ),
                              _buildDivider(),
                              _buildInfoRow(Icons.access_time, 'Time', jobTime),
                              _buildDivider(),
                              InkWell(
                                onTap: () => _launchMaps(siteLocation),
                                child: _buildInfoRow(
                                  Icons.location_on,
                                  'Location',
                                  siteLocation,
                                  isLink: true,
                                ),
                              ),
                              _buildDivider(),
                              _buildDescriptionSection(),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Status Section
                    if (isJobAccepted || !canAcceptJobs)
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildStatusBanner(
                            isJobAccepted
                                ? 'This job request has already been accepted'
                                : 'This job request is not for your industry',
                            canAcceptJobs ? Colors.red : Colors.orange,
                            isJobAccepted ? Colors.red : Colors.orange,
                          ),
                        ),
                      ),

                    // Action Buttons
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          child: Column(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap:
                                      (isLoading ||
                                          isJobAccepted ||
                                          !canAcceptJobs)
                                      ? null
                                      : _acceptNotification,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient:
                                          (isLoading ||
                                              isJobAccepted ||
                                              !canAcceptJobs)
                                          ? LinearGradient(
                                              colors: [
                                                Colors.grey.withOpacity(0.3),
                                                Colors.grey.withOpacity(0.3),
                                              ],
                                            )
                                          : const LinearGradient(
                                              colors: [
                                                Colors.white,
                                                Color(0xFFF0F0F0),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color:
                                              (isLoading ||
                                                  isJobAccepted ||
                                                  !canAcceptJobs)
                                              ? Colors.grey
                                              : const Color(0xFF1E3A8A),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Accept Request',
                                          style: TextStyle(
                                            color:
                                                (isLoading ||
                                                    isJobAccepted ||
                                                    !canAcceptJobs)
                                                ? Colors.grey
                                                : const Color(0xFF1E3A8A),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isLoading
                                      ? null
                                      : _fetchNotificationDetails,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.refresh,
                                          color: isLoading
                                              ? Colors.grey
                                              : const Color(0xFF1E3A8A),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Refresh',
                                          style: TextStyle(
                                            color: isLoading
                                                ? Colors.grey
                                                : const Color(0xFF1E3A8A),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
              if (isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
