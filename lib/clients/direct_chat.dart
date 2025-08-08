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

const String GEOAPIFY_API_KEY = 'c27414be0c794f38a1f0215423a01e6d';

class PDFViewerPage extends StatelessWidget {
  final String url;
  final String fileName;

  const PDFViewerPage({Key? key, required this.url, required this.fileName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: FutureBuilder<String>(
        future: _downloadFile(url),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading PDF: ${snapshot.error}'));
          }
          if (snapshot.hasData) {
            return PDFView(
              filePath: snapshot.data!,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: false,
              pageFling: false,
            );
          }
          return Center(child: Text('Unable to load PDF'));
        },
      ),
    );
  }

  Future<String> _downloadFile(String url) async {
    final response = await http.get(Uri.parse(url));
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/$fileName';
    await File(tempPath).writeAsBytes(response.bodyBytes);
    return tempPath;
  }
}

class ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  final String imageName;

  const ImageViewerPage({
    Key? key,
    required this.imageUrl,
    required this.imageName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(imageName),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Error loading image'),
                  ],
                ),
              );
            },
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
  State<DirectPage> createState() => _DirectPageState();
}

class _DirectPageState extends State<DirectPage> {
  List<types.Message> _messages = [];
  types.User? _currentUser;
  String? appointmentId;
  bool isChatClosed = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _listenForMessages();
    _getAppointmentId();
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
            // Close chat if explicitly closed or unpaid
            isChatClosed = status == 'Closed' || paymentStatus != 'Paid';
          });
        }
      }
    });
  }

  Future<void> _handleFileOpen(types.FileMessage message) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${message.name}';

      // Download the file
      final response = await http.get(Uri.parse(message.uri));
      await File(filePath).writeAsBytes(response.bodyBytes);

      final mimeType = message.mimeType?.toLowerCase() ?? '';

      if (mimeType.contains('pdf')) {
        // Open PDF in the custom viewer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFViewerPage(
              url: message.uri,
              fileName: message.name,
            ),
          ),
        );
      } else if (mimeType.contains('doc') || mimeType.contains('docx')) {
        // Open DOC/DOCX files using open_filex
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
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
      });
    });
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
          return {
            'longitude': coordinates[0],
            'latitude': coordinates[1],
          };
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
      // Create a Google Maps URL for navigation
      final encodedLocation = Uri.encodeComponent(location);
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$encodedLocation';

      // First geocode the address
      final coordinates = await _geocodeAddress(location);

      if (coordinates != null) {
        // Get static map URL using coordinates
        final staticMapUrl = _createStaticMapUrl(
            coordinates['longitude']!, coordinates['latitude']!);

        // Send the static map image
        final imageMessage = types.ImageMessage(
          author: _currentUser!,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          name: 'Location Map',
          size: 0, // Size will be determined when image loads
          uri: staticMapUrl,
          width: 600, // Match the width from the static map URL
          height: 400, // Match the height from the static map URL
          metadata: {
            'type': 'location',
            'navigationUrl': mapsUrl,
            'location': location,
          },
        );

        _addMessage(imageMessage);
      }

      // Send the location details as text
      final messageText = '''
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

    final whatToInspectController =
        TextEditingController(text: data['WhatToInspect'] ?? '');
    final hostDetailsController =
        TextEditingController(text: data['HostDetails'] ?? '');
    final siteNameController =
        TextEditingController(text: data['SiteName'] ?? '');
    final siteLocationController =
        TextEditingController(text: data['siteLocation'] ?? '');
    final jobDateController =
        TextEditingController(text: data['jobDate'] ?? '');
    final jobTimeController =
        TextEditingController(text: data['jobTime'] ?? '');
    final companyNameController =
        TextEditingController(text: data['CompanyName'] ?? '');
    final regNoController = TextEditingController(text: data['RegNo'] ?? '');
    final contactPersonController =
        TextEditingController(text: data['ContactPerson'] ?? '');
    final contactNumberController =
        TextEditingController(text: data['ContactNumber'] ?? '');
    final emailAddressController =
        TextEditingController(text: data['EmailAddress'] ?? '');
    final physicalAddressController =
        TextEditingController(text: data['PhysicalAddress'] ?? '');
    final notesController = TextEditingController(text: data['Notes'] ?? '');

    void sendToChat() {
      if (_currentUser != null) {
        // Share location separately if it exists
        if (siteLocationController.text.isNotEmpty) {
          _handleLocationShare(siteLocationController.text);
        }

        final messageText = '''
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Request Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(225, 0, 74, 173),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    _buildEditField('What to Inspect', whatToInspectController),
                    _buildEditField('Host Details', hostDetailsController),
                    _buildEditField('Site Name', siteNameController),
                    _buildEditField('Site Location', siteLocationController),
                    _buildEditField('Job Date', jobDateController),
                    _buildEditField('Job Time', jobTimeController),
                    Divider(height: 20),
                    Text(
                      'Business Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(225, 0, 74, 173),
                      ),
                    ),
                    _buildEditField('Company Name', companyNameController),
                    _buildEditField('Registration Number', regNoController),
                    _buildEditField('Contact Person', contactPersonController),
                    _buildEditField('Contact Number', contactNumberController),
                    _buildEditField('Email Address', emailAddressController),
                    _buildEditField(
                        'Physical Address', physicalAddressController),
                    _buildEditField('Notes', notesController),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: Text('Close', style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: sendToChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(225, 0, 74, 173),
                    ),
                    child: Text('Send to Chat',
                        style: TextStyle(color: Colors.white)),
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
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Color.fromARGB(225, 0, 74, 173)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Color.fromARGB(225, 0, 74, 173)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Color.fromARGB(225, 0, 74, 173)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: Color.fromARGB(225, 0, 74, 173), width: 2),
          ),
        ),
      ),
    );
  }

  void _addMessage(types.Message message) async {
    if (_currentUser != null) {
      setState(() {
        _messages.insert(0, message);
      });

      // Write message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(message.id)
          .set(message.toJson());

      // Update inbox metadata for ordering
      final preview = message is types.TextMessage
          ? message.text
          : (message is types.ImageMessage
              ? '[Image] ${message.name}'
              : (message is types.FileMessage ? '[File] ${message.name}' : '[Message]'));

      await FirebaseFirestore.instance.collection('inbox').doc(widget.chatId).set({
        'lastMessage': preview,
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Photo'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('File'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      final file = File(filePath);

      try {
        // Create a reference in Firebase Storage with a unique filename
        final storageRef = FirebaseStorage.instance.ref().child(
            'uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName');
        final uploadTask = storageRef.putFile(file);

        // Wait for the upload to complete
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
        // Handle upload errors
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload file: ${e.toString()}')));
      }
    }
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      final file = File(result.path);
      final fileName = result.name;

      final storageRef =
          FirebaseStorage.instance.ref().child('uploads/$fileName');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share_rounded),
            onPressed: _showRequestDetails,
          ),
        ],
      ),
      body: Column(
        children: [
          if (isChatClosed)
            Container(
              color: Colors.grey[300],
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.red),
                  SizedBox(width: 8),
                  Text('This chat is closed. No new messages can be sent.'),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                if (isChatClosed)
                  AbsorbPointer(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
