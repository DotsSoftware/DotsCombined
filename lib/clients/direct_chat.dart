import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient

const String GEOAPIFY_API_KEY = 'c27414be0c794f38a1f0215423a01e6d';

// Placeholder ChatController class (custom implementation)
class ChatController extends ChangeNotifier {
  List<types.Message> messages;
  final void Function(types.PartialText)? onSend;
  final VoidCallback? onAttachmentTap;

  ChatController({required this.messages, this.onSend, this.onAttachmentTap});

  void dispose() {
    super.dispose();
  }
}

class PDFViewerPage extends StatefulWidget {
  final String url;
  final String fileName;

  const PDFViewerPage({Key? key, required this.url, required this.fileName})
    : super(key: key);

  @override
  _PDFViewerPageState createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _title() {
    return Text(
      widget.fileName,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _appBarImage() {
    return Container(
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
            const Icon(Icons.error_outline, color: Color(0xFF1E3A8A), size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      children: [
                        _appBarImage(),
                        const SizedBox(width: 16),
                        Expanded(child: _title()),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.arrow_back,
                                color: Colors.white.withOpacity(0.8),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // PDF Viewer
              Expanded(
                child: FutureBuilder<String>(
                  future: _downloadFile(widget.url),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF1E3A8A),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 24,
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
                                      'Error loading PDF: ${snapshot.error}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasData) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: PDFView(
                            filePath: snapshot.data!,
                            enableSwipe: true,
                            swipeHorizontal: true,
                            autoSpacing: false,
                            pageFling: false,
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
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
                                const Text(
                                  'Unable to load PDF',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _downloadFile(String url) async {
    final response = await http.get(Uri.parse(url));
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/${widget.fileName}';
    await File(tempPath).writeAsBytes(response.bodyBytes);
    return tempPath;
  }
}

class ImageViewerPage extends StatefulWidget {
  final String imageUrl;
  final String imageName;

  const ImageViewerPage({
    Key? key,
    required this.imageUrl,
    required this.imageName,
  }) : super(key: key);

  @override
  _ImageViewerPageState createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _title() {
    return Text(
      widget.imageName,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _appBarImage() {
    return Container(
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
            const Icon(Icons.error_outline, color: Color(0xFF1E3A8A), size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      children: [
                        _appBarImage(),
                        const SizedBox(width: 16),
                        Expanded(child: _title()),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.arrow_back,
                                color: Colors.white.withOpacity(0.8),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Image Viewer
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(
                          widget.imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1E3A8A),
                                ),
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Error loading image',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
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
}

class DirectPage extends StatefulWidget {
  final String chatId;

  const DirectPage({Key? key, required this.chatId}) : super(key: key);

  @override
  _DirectPageState createState() => _DirectPageState();
}

class _DirectPageState extends State<DirectPage> with TickerProviderStateMixin {
  List<types.Message> _messages = [];
  types.User? _currentUser;
  String? appointmentId;
  bool isChatClosed = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late ChatController _chatController;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeUser();
    _listenForMessages();
    _getAppointmentId();
    _chatController = ChatController(
      messages: _messages,
      onSend: _handleSendPressed,
      onAttachmentTap: _handleAttachmentPressed,
    );
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

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _listenForRequestStatus() {
    if (appointmentId == null) return;

    FirebaseFirestore.instance
        .collection('notifications')
        .doc(appointmentId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            final String? paymentStatus = data?['paymentStatus'] as String?;
            final String status = data?['status'] as String? ?? 'Open';
            if (mounted) {
              setState(() {
                isChatClosed = status == 'Closed' || paymentStatus != 'Paid';
              });
            }
          }
        });
  }

  void _handleFileOpen(BuildContext context, types.Message message) {
    Future.microtask(() async {
      try {
        if (message is types.FileMessage) {
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/${message.name}';

          final response = await http.get(Uri.parse(message.uri));
          await File(filePath).writeAsBytes(response.bodyBytes);

          final mimeType = message.mimeType?.toLowerCase() ?? '';

          if (mimeType.contains('pdf')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PDFViewerPage(url: message.uri, fileName: message.name),
              ),
            );
          } else if (mimeType.contains('doc') || mimeType.contains('docx')) {
            final result = await OpenFilex.open(filePath);
            if (result.type != ResultType.done) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not open file: ${result.message}'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _getAppointmentId() async {
    var doc = await FirebaseFirestore.instance
        .collection('inbox')
        .doc(widget.chatId)
        .get();
    if (doc.exists) {
      setState(() {
        appointmentId = doc.data()?['appointmentId'];
      });
      _listenForRequestStatus();
    }
  }

  Future<void> _initializeUser() async {
    User? firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      firebaseUser = (await FirebaseAuth.instance.signInAnonymously()).user;
    }

    if (firebaseUser != null) {
      setState(() {
        _currentUser = types.User(
          id: firebaseUser!.uid,
          firstName: firebaseUser.email?.split('@')[0] ?? 'Anon',
        );
      });
    }
  }

  void _listenForMessages() {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((querySnapshot) {
          final messages = querySnapshot.docs.map((doc) {
            return types.Message.fromJson(doc.data() as Map<String, dynamic>);
          }).toList();

          setState(() {
            _messages = messages;
            _chatController.messages = messages;
          });
        });
  }

  Future<types.User?> _resolveUser(String userId) async {
    if (userId == _currentUser?.id) {
      return _currentUser;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return types.User(
          id: userId,
          firstName: data['firstName'] ?? 'Unknown',
          lastName: data['lastName'],
          imageUrl: data['imageUrl'],
        );
      }
    } catch (e) {
      print('Error resolving user: $e');
    }
    return types.User(id: userId, firstName: 'Unknown');
  }

  Future<Map<String, double>?> _geocodeAddress(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url =
        'https://api.geoapify.com/v1/geocode/search?text=$encodedAddress&apiKey=$GEOAPIFY_API_KEY';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].length > 0) {
          final coordinates = data['features'][0]['geometry']['coordinates'];
          return {'longitude': coordinates[0], 'latitude': coordinates[1]};
        }
      }
      return null;
    } catch (e) {
      print('Geocoding error: $e');
      return null;
    }
  }

  String _createStaticMapUrl(double longitude, double latitude) {
    return 'https://maps.geoapify.com/v1/staticmap'
        '?style=osm-carto'
        '&width=600'
        '&height=400'
        '&center=lonlat:$longitude,$latitude'
        '&zoom=14'
        '&marker=lonlat:$longitude,$latitude;color:%23ff0000;size:medium'
        '&apiKey=$GEOAPIFY_API_KEY';
  }

  void _handleLocationShare(String location) async {
    if (_currentUser != null) {
      final encodedLocation = Uri.encodeComponent(location);
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$encodedLocation';

      final coordinates = await _geocodeAddress(location);

      if (coordinates != null) {
        final staticMapUrl = _createStaticMapUrl(
          coordinates['longitude']!,
          coordinates['latitude']!,
        );

        final imageMessage = types.ImageMessage(
          author: _currentUser!,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          name: 'Location Map',
          size: 0,
          uri: staticMapUrl,
          width: 600,
          height: 400,
          metadata: {
            'type': 'location',
            'navigationUrl': mapsUrl,
            'location': location,
          },
        );

        _addMessage(imageMessage);
      }

      final messageText =
          '''
📍 Location: $location
${coordinates != null ? 'Tap the map above to navigate' : 'Click here to navigate'}''';

      final textMessage = types.TextMessage(
        author: _currentUser!,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: messageText,
        metadata: {'type': 'location', 'url': mapsUrl},
      );

      _addMessage(textMessage);
    }
  }

  void _showRequestDetails() async {
    if (appointmentId == null) return;

    final request = await FirebaseFirestore.instance
        .collection('notifications')
        .doc(appointmentId)
        .get();

    if (!request.exists) return;

    final data = request.data() as Map<String, dynamic>;

    final whatToInspectController = TextEditingController(
      text: data['WhatToInspect'] ?? '',
    );
    final hostDetailsController = TextEditingController(
      text: data['HostDetails'] ?? '',
    );
    final siteNameController = TextEditingController(
      text: data['SiteName'] ?? '',
    );
    final siteLocationController = TextEditingController(
      text: data['siteLocation'] ?? '',
    );
    final jobDateController = TextEditingController(
      text: data['jobDate'] ?? '',
    );
    final jobTimeController = TextEditingController(
      text: data['jobTime'] ?? '',
    );
    final companyNameController = TextEditingController(
      text: data['CompanyName'] ?? '',
    );
    final regNoController = TextEditingController(text: data['RegNo'] ?? '');
    final contactPersonController = TextEditingController(
      text: data['ContactPerson'] ?? '',
    );
    final contactNumberController = TextEditingController(
      text: data['ContactNumber'] ?? '',
    );
    final emailAddressController = TextEditingController(
      text: data['EmailAddress'] ?? '',
    );
    final physicalAddressController = TextEditingController(
      text: data['PhysicalAddress'] ?? '',
    );
    final notesController = TextEditingController(text: data['Notes'] ?? '');

    void sendToChat() {
      if (_currentUser != null) {
        if (siteLocationController.text.isNotEmpty) {
          _handleLocationShare(siteLocationController.text);
        }

        final messageText =
            '''
**Request Details:**

**What to Inspect:** ${whatToInspectController.text}
**Host Details:** ${hostDetailsController.text}
**Site Name:** ${siteNameController.text}
**Job Date:** ${jobDateController.text}
**Job Time:** ${jobTimeController.text}

**Company Name:** ${companyNameController.text}
**Registration Number:** ${regNoController.text}
**Contact Person:** ${contactPersonController.text}
**Contact Number:** ${contactNumberController.text}
**Email Address:** ${emailAddressController.text}
**Physical Address:** ${physicalAddressController.text}

**Notes:** ${notesController.text}
''';

        final textMessage = types.TextMessage(
          author: _currentUser!,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: messageText,
        );

        _addMessage(textMessage);
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white.withOpacity(0.95),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
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
                    child: const Icon(
                      Icons.info,
                      color: Color(0xFF1E3A8A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Request Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _buildEditField('What to Inspect', whatToInspectController),
                    _buildEditField('Host Details', hostDetailsController),
                    _buildEditField('Site Name', siteNameController),
                    _buildEditField('Site Location', siteLocationController),
                    _buildEditField('Job Date', jobDateController),
                    _buildEditField('Job Time', jobTimeController),
                    Divider(
                      height: 20,
                      thickness: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    Text(
                      'Business Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    _buildEditField('Company Name', companyNameController),
                    _buildEditField('Registration Number', regNoController),
                    _buildEditField('Contact Person', contactPersonController),
                    _buildEditField('Contact Number', contactNumberController),
                    _buildEditField('Email Address', emailAddressController),
                    _buildEditField(
                      'Physical Address',
                      physicalAddressController,
                    ),
                    _buildEditField('Notes', notesController),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: sendToChat,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                        child: const Center(
                          child: Text(
                            'Send to Chat',
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
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
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _addMessage(types.Message message) async {
    if (_currentUser != null) {
      setState(() {
        _messages.insert(0, message);
        _chatController.messages = _messages;
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(message.id)
          .set(message.toJson());
      final preview = message is types.TextMessage
          ? message.text
          : (message is types.ImageMessage
                ? '[Image] ${message.name}'
                : (message is types.FileMessage
                      ? '[File] ${message.name}'
                      : '[Message]'));

      await FirebaseFirestore.instance
          .collection('inbox')
          .doc(widget.chatId)
          .set({
            'lastMessage': preview,
            'lastMessageTime': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white.withOpacity(0.95),
      builder: (BuildContext context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                child: const Text(
                  'Choose Attachment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _handleImageSelection();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 16),
                        Text(
                          'Photo',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _handleFileSelection();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file,
                          color: Color(0xFF1E3A8A),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'File',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel, color: Colors.red),
                        const SizedBox(width: 16),
                        Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
    );
  }

  Future<void> _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      final file = File(filePath);

      try {
        final storageRef = FirebaseStorage.instance.ref().child(
          'Uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName',
        );
        final uploadTask = storageRef.putFile(file);

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        if (_currentUser != null) {
          final message = types.FileMessage(
            author: _currentUser!,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: const Uuid().v4(),
            mimeType: lookupMimeType(filePath),
            name: fileName,
            size: result.files.single.size,
            uri: downloadUrl,
          );

          _addMessage(message);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload file: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      final file = File(result.path);
      final fileName = result.name;

      final storageRef = FirebaseStorage.instance.ref().child(
        'Uploads/$fileName',
      );
      final uploadTask = storageRef.putFile(file);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);

      if (_currentUser != null) {
        final message = types.ImageMessage(
          author: _currentUser!,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          height: image.height.toDouble(),
          id: const Uuid().v4(),
          name: fileName,
          size: bytes.length,
          uri: downloadUrl,
          width: image.width.toDouble(),
        );

        _addMessage(message);
      }
    }
  }

  void _handleSendPressed(types.PartialText message) {
    if (_currentUser != null) {
      final textMessage = types.TextMessage(
        author: _currentUser!,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: message.text,
      );

      _addMessage(textMessage);
    }
  }

  Widget _title() {
    return const Text(
      'Chat',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _appBarImage() {
    return Container(
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
            const Icon(Icons.error_outline, color: Color(0xFF1E3A8A), size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      children: [
                        _appBarImage(),
                        const SizedBox(width: 16),
                        _title(),
                        const Spacer(),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.arrow_back,
                                color: Colors.white.withOpacity(0.8),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showRequestDetails,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  Icons.ios_share_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Closed Chat Banner
              if (isChatClosed)
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, color: Colors.red, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This chat is closed. No new messages can be sent.',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Chat UI
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                    ),
                    if (isChatClosed)
                      Container(color: Colors.black.withOpacity(0.3)),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
