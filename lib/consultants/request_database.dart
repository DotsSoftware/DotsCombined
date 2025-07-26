
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'direct_page.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient

class RequestDatabase extends StatefulWidget {
  const RequestDatabase({Key? key}) : super(key: key);

  @override
  _RequestDatabaseState createState() => _RequestDatabaseState();
}

class _RequestDatabaseState extends State<RequestDatabase> with TickerProviderStateMixin {
  String filter = 'All';
  late String currentUserId;
  bool _isLoading = false;
  String? errorMessage;
  Map<String, Map<String, String>> documentFields = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _getCurrentUserId();
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
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

  void _getCurrentUserId() {
    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        currentUserId = user.uid;
      });
    } else {
      setState(() {
        currentUserId = '';
        errorMessage = 'No user is currently signed in.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user is currently signed in.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUpdateDocument(String fieldName, String requestId) async {
    setState(() => _isLoading = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.first 
      .bytes != null) {
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String originalFileName = result.files.first.name;
        String uniqueFileName = '${timestamp}_$originalFileName';

        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('client request')
            .child(FirebaseAuth.instance.currentUser?.email ?? 'anonymous')
            .child(requestId)
            .child(uniqueFileName);

        UploadTask uploadTask = storageRef.putData(result.files.first.bytes!);

        await uploadTask.whenComplete(() async {
          String downloadUrl = await storageRef.getDownloadURL();
          setState(() {
            documentFields[fieldName] = {
              'name': originalFileName,
              'url': downloadUrl,
            };
          });
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error uploading document: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading document: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _viewDocument(String url) async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch document';
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error opening document: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening document: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToChat(QueryDocumentSnapshot appointment) async {
    setState(() => _isLoading = true);
    try {
      final data = appointment.data() as Map<String, dynamic>;
      final String? clientId = data['clientId'] as String?;
      final String? consultantId = data['acceptedConsultantId'] as String?;

      if (clientId == null || consultantId == null || clientId.isEmpty || consultantId.isEmpty) {
        throw 'Missing or empty participant information';
      }

      final chatId = '${clientId}_$consultantId';
      await FirebaseFirestore.instance.collection('inbox').doc(chatId).set({
        'participants': [clientId, consultantId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'appointmentId': appointment.id,
      }, SetOptions(merge: true));

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DirectPage(chatId: chatId),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error starting chat: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting chat: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRefundRequest(QueryDocumentSnapshot request) async {
    final data = request.data() as Map<String, dynamic>;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      setState(() {
        errorMessage = 'Error: User not logged in';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: User not logged in'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      DateTime requestTime = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      Duration timeSinceRequest = DateTime.now().difference(requestTime);
      bool isWithinHour = timeSinceRequest.inHours < 1;

      await FirebaseFirestore.instance
          .collection('refunds')
          .doc(user.email)
          .collection('requests')
          .add({
        'requestId': request.id,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'originalRequestData': {
          'jobDate': data['jobDate'] ?? '',
          'industry_type': data['industry_type'] ?? '',
          'jobDescription': data['jobDescription'] ?? '',
          'requestTimestamp': data['timestamp'],
        },
        'refundDetails': {
          'isWithinHour': isWithinHour,
          'fullRefundEligible': isWithinHour,
          'consultantFee': data['consultantFee'] ?? 0,
          'travelCost': data['travelCost'] ?? 0,
          'calculatedRefundAmount': isWithinHour
              ? ((data['consultantFee'] ?? 0) + (data['travelCost'] ?? 0))
              : ((data['consultantFee'] ?? 0) * 0.5 + (data['travelCost'] ?? 0)),
        },
        'clientId': user.uid,
        'clientEmail': user.email,
        'consultantId': data['acceptedConsultantId'],
      });

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(request.id)
          .update({'status': 'Cancelled'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refund request submitted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error submitting refund request: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting refund request: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _closeRequest(QueryDocumentSnapshot request) async {
    setState(() => _isLoading = true);
    try {
      final requestDocRef = FirebaseFirestore.instance.collection('client request').doc(request.id);
      final requestDoc = await requestDocRef.get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final data = requestDoc.data() as Map<String, dynamic>;
      final String? clientId = data['clientId'] as String?;
      final String? consultantId = data['acceptedConsultantId'] as String?;

      if (clientId == null || consultantId == null) {
        throw Exception('Missing participant information');
      }

      await requestDocRef.update({
        'status': 'Closed',
        'closedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('inbox')
          .doc('${clientId}_$consultantId')
          .update({
        'status': 'Closed',
        'closedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request closed successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error closing request: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error closing request: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'Closed':
        return Icons.cancel;
      case 'Cancelled':
        return Icons.money_off;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'Closed':
        return Colors.red;
      case 'Cancelled':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildModernCard({required String title, required Widget child, IconData? icon}) {
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

  Widget _buildReadOnlyField({required String label, required TextEditingController controller}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        readOnly: true,
        enabled: false,
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildDocumentField(String fieldName, String requestId) {
    if (documentFields[fieldName] == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Text(
                documentFields[fieldName]?['name'] ?? 'Document',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.visibility, color: Color(0xFF1E3A8A)),
            onPressed: () => _viewDocument(documentFields[fieldName]!['url']!),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, QueryDocumentSnapshot request) {
    final data = request.data() as Map<String, dynamic>;
    setState(() {
      documentFields = Map<String, Map<String, String>>.from(
          data['Documents'] as Map<dynamic, dynamic>? ?? {});
    });

    TextEditingController whatToInspectController =
        TextEditingController(text: data['WhatToInspect'] ?? '');
    TextEditingController hostDetailsController =
        TextEditingController(text: data['HostDetails'] ?? '');
    TextEditingController siteNameController =
        TextEditingController(text: data['SiteName'] ?? '');
    TextEditingController siteLocationController =
        TextEditingController(text: data['siteLocation'] ?? '');
    TextEditingController jobDateController =
        TextEditingController(text: data['jobDate'] ?? '');
    TextEditingController jobTimeController =
        TextEditingController(text: data['jobTime'] ?? '');
    TextEditingController companyNameController =
        TextEditingController(text: data['CompanyName'] ?? '');
    TextEditingController regNoController =
        TextEditingController(text: data['RegNo'] ?? '');
    TextEditingController contactPersonController =
        TextEditingController(text: data['ContactPerson'] ?? '');
    TextEditingController contactNumberController =
        TextEditingController(text: data['ContactNumber'] ?? '');
    TextEditingController emailAddressController =
        TextEditingController(text: data['EmailAddress'] ?? '');
    TextEditingController physicalAddressController =
        TextEditingController(text: data['PhysicalAddress'] ?? '');
    TextEditingController notesController =
        TextEditingController(text: data['Notes'] ?? '');

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool isRequestActive = data['status'] == 'accepted';
        bool hasAcceptedConsultant = data.containsKey('acceptedConsultantId') &&
            data['acceptedConsultantId'] != null;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white.withOpacity(0.15),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Request Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReadOnlyField(label: 'What to Inspect', controller: whatToInspectController),
                        _buildReadOnlyField(label: 'Host Details', controller: hostDetailsController),
                        _buildReadOnlyField(label: 'Site Name', controller: siteNameController),
                        _buildReadOnlyField(label: 'Site Location', controller: siteLocationController),
                        _buildReadOnlyField(label: 'Job Date', controller: jobDateController),
                        _buildReadOnlyField(label: 'Job Time', controller: jobTimeController),
                        const Divider(color: Colors.white, height: 20),
                        const Text(
                          'Business Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildReadOnlyField(label: 'Company Name', controller: companyNameController),
                        _buildReadOnlyField(label: 'Registration Number', controller: regNoController),
                        _buildReadOnlyField(label: 'Contact Person', controller: contactPersonController),
                        _buildReadOnlyField(label: 'Contact Number', controller: contactNumberController),
                        _buildReadOnlyField(label: 'Email Address', controller: emailAddressController),
                        _buildReadOnlyField(label: 'Physical Address', controller: physicalAddressController),
                        _buildReadOnlyField(label: 'Notes', controller: notesController),
                        const Divider(color: Colors.white, height: 20),
                        const Text(
                          'Documents',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int i = 1; i <= 5; i++)
                          if (documentFields.containsKey('Document$i'))
                            _buildDocumentField('Document$i', request.id),
                        const SizedBox(height: 16),
                        if (hasAcceptedConsultant && isRequestActive)
                          Column(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showCloseRequestDialog(context, request),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: const Text(
                                      'Close Request',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _navigateToChat(request);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.chat,
                                          color: Color(0xFF1E3A8A),
                                          size: 24,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Chat with Client',
                                          style: TextStyle(
                                            color: Color(0xFF1E3A8A),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
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
                                  onTap: () => _showRefundDialog(context, request),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    child: const Text(
                                      'Cancel & Refund',
                                      style: TextStyle(
                                        color: Color(0xFF1E3A8A),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCloseRequestDialog(BuildContext context, QueryDocumentSnapshot request) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white.withOpacity(0.15),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Close Request',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to close this request?',
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                Text(
                  'This will:\n• Mark the request as completed\n• Prevent further chat messages\n• Close the communication channel',
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          await _closeRequest(request);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'Close Request',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRefundDialog(BuildContext context, QueryDocumentSnapshot request) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white.withOpacity(0.15),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Refunds & Rules',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Full refunds should be requested within an hour of placing the request.',
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Thereafter, only travel costs are refunded in full, but only 50% of the consultant\'s fees will be paid back.',
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          await _submitRefundRequest(request);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.white, Color(0xFFF0F0F0)],
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
                          child: const Text(
                            'Request Refund',
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
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
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFF1E3A8A),
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Jobs',
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
                  if (errorMessage != null)
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  errorMessage!,
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

                  // Request List
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: currentUserId.isEmpty
                          ? null
                          : FirebaseFirestore.instance
                              .collection('notifications')
                              .where('acceptedConsultantId', isEqualTo: currentUserId)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (currentUserId.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.work_off,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Please sign in to view jobs.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.work_off,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No jobs available.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        var requests = snapshot.data!.docs;
                        if (filter != 'All') {
                          requests = requests.where((doc) => doc['status'] == filter).toList();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            var request = requests[index];
                            final data = request.data() as Map<String, dynamic>;

                            return SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: _buildModernCard(
                                  title: 'Job #${index + 1}',
                                  icon: _getStatusIcon(data['status'] ?? ''),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(data['status'] ?? '').withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              _getStatusIcon(data['status'] ?? ''),
                                              color: _getStatusColor(data['status'] ?? ''),
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Status: ${data['status'] ?? 'N/A'}',
                                              style: TextStyle(
                                                color: _getStatusColor(data['status'] ?? ''),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Job Date: ${data['jobDate'] ?? 'N/A'}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Time: ${data['jobTime'] ?? 'N/A'}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Location: ${data['siteLocation']?.isNotEmpty == true ? data['siteLocation'] : 'N/A'}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Category: ${data['industry_type'] ?? 'N/A'}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Description: ${data['jobDescription'] ?? 'N/A'}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => _showEditDialog(context, request),
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    vertical: 12, horizontal: 16),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: Colors.white.withOpacity(0.3)),
                                                ),
                                                child: const Text(
                                                  'View Details',
                                                  style: TextStyle(
                                                    color: Color(0xFF1E3A8A),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (data['status'] == 'accepted')
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => _navigateToChat(request),
                                                borderRadius: BorderRadius.circular(12),
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  child: const Icon(
                                                    Icons.chat,
                                                    color: Color(0xFF1E3A8A),
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Bottom Navigation
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: BottomNavigationBar(
                      backgroundColor: Colors.blueGrey,
                      elevation: 0,
                      items: const [
                        BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All'),
                        BottomNavigationBarItem(
                            icon: Icon(Icons.check_circle), label: 'Active'),
                        BottomNavigationBarItem(
                            icon: Icon(Icons.hourglass_empty), label: 'Pending'),
                        BottomNavigationBarItem(icon: Icon(Icons.cancel), label: 'Closed'),
                      ],
                      selectedItemColor: const Color(0xFF1E3A8A),
                      unselectedItemColor: Colors.white.withOpacity(0.7),
                      onTap: (index) {
                        setState(() {
                          switch (index) {
                            case 0:
                              filter = 'All';
                              break;
                            case 1:
                              filter = 'accepted';
                              break;
                            case 2:
                              filter = 'pending';
                              break;
                            case 3:
                              filter = 'Closed';
                              break;
                          }
                        });
                      },
                      currentIndex: ['All', 'accepted', 'pending', 'Closed'].indexOf(filter),
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
