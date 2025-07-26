import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

const String GEOAPIFY_API_KEY = 'c27414be0c794f38a1f0215423a01e6d';

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
  Timer? _locationTimer;
  String? _clientId;
  String? _consultantId;
  bool _twoHourNotificationSent = false;
  bool _oneHourNotificationSent = false;
  bool isChatClosed = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _listenForMessages();
    _getAppointmentId();
    if (kIsWeb) {
      _setupLocationSharing();
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _listenForRequestStatus() {
    if (appointmentId == null) return;

    FirebaseFirestore.instance
        .collection('client request')
        .doc(appointmentId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final status = snapshot.data()?['status'] ?? 'Open';
        if (mounted) {
          setState(() {
            isChatClosed = status == 'Closed';
          });
        }
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

  Future<void> _setupLocationSharing() async {
    // Get participant IDs from inbox collection
    var inboxDoc = await FirebaseFirestore.instance
        .collection('inbox')
        .doc(widget.chatId)
        .get();

    if (inboxDoc.exists) {
      List<dynamic> participants = inboxDoc.data()?['participants'] ?? [];
      if (participants.length == 2) {
        _clientId = participants[0];
        _consultantId = participants[1];

        // Start periodic check every minute
        _locationTimer = Timer.periodic(Duration(minutes: 1), (timer) {
          _checkAndShareLocation();
        });
      }
    }
  }

  Future<void> _scheduleLocationSharing() async {
    // Get the most recent notification document
    var notificationsQuery = await FirebaseFirestore.instance
        .collection('notifications')
        .where('clientId', isEqualTo: _clientId)
        .where('acceptedConsultantId', isEqualTo: _consultantId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (notificationsQuery.docs.isEmpty) return;

    var notificationDoc = notificationsQuery.docs.first;
    var jobDate = notificationDoc.data()['jobDate'];
    var jobTime = notificationDoc.data()['jobTime'];

    if (jobDate == null || jobTime == null) return;

    // Immediate check in case we're already within the notification window
    await _checkAndShareLocation();
  }

  Future<void> _checkAndShareLocation() async {
    try {
      var notificationsQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('clientId', isEqualTo: _clientId)
          .where('acceptedConsultantId', isEqualTo: _consultantId)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (notificationsQuery.docs.isEmpty) {
        return;
      }

      // Sort notifications by timestamp
      final sortedDocs = notificationsQuery.docs
          .map((doc) {
            final data = doc.data();
            final timestamp = data['acceptedTimestamp'] as Timestamp?;
            return {
              'data': data,
              'timestamp': timestamp?.toDate(),
            };
          })
          .where((doc) => doc['timestamp'] != null)
          .toList()
        ..sort((a, b) {
          final DateTime timeA = a['timestamp'] as DateTime;
          final DateTime timeB = b['timestamp'] as DateTime;
          return timeB.compareTo(timeA);
        });

      if (sortedDocs.isEmpty) return;

      var notificationData = sortedDocs.first['data'] as Map<String, dynamic>;
      var jobDate = notificationData['jobDate'];
      var jobTime = notificationData['jobTime'];

      if (jobDate == null || jobTime == null) return;

      var appointmentDateTime = _parseDateTime(jobDate, jobTime);
      if (appointmentDateTime == null) return;

      var now = DateTime.now();
      var twoHoursBefore = appointmentDateTime.subtract(Duration(hours: 2));
      var oneHourBefore = appointmentDateTime.subtract(Duration(hours: 1));

      // Check if we're within 5 minutes of the target times to prevent duplicate sends
      bool isNearTwoHourMark = now.isAfter(twoHoursBefore) &&
          now.isBefore(twoHoursBefore.add(Duration(minutes: 5)));
      bool isNearOneHourMark = now.isAfter(oneHourBefore) &&
          now.isBefore(oneHourBefore.add(Duration(minutes: 5)));

      // Send two-hour notification
      if (!_twoHourNotificationSent && isNearTwoHourMark) {
        await _shareCurrentLocation("2 hours before appointment");
        _twoHourNotificationSent = true;
      }

      // Send one-hour notification
      if (!_oneHourNotificationSent && isNearOneHourMark) {
        await _shareCurrentLocation("1 hour before appointment");
        _oneHourNotificationSent = true;
      }

      // If both notifications have been sent, stop the timer
      if (_oneHourNotificationSent && _twoHourNotificationSent) {
        _locationTimer?.cancel();
      }
    } catch (e, stackTrace) {
      print('Error in _checkAndShareLocation: $e');
      print('Stack trace: $stackTrace');
    }
  }

  DateTime? _parseDateTime(String date, String time) {
    try {
      // Parse date in format "2024-12-11"
      var dateComponents = date.split('-');

      // Parse time in format "11:25"
      var timeComponents = time.split(':');

      return DateTime(
        int.parse(dateComponents[0]), // year
        int.parse(dateComponents[1]), // month
        int.parse(dateComponents[2]), // day
        int.parse(timeComponents[0]), // hour
        int.parse(timeComponents[1]), // minute
      );
    } catch (e) {
      print('Date parsing error: $e');
      return null;
    }
  }

  Future<void> _shareCurrentLocation(String timing) async {
    try {
      print('Starting location sharing for $timing');

      // Check for current user
      if (_currentUser == null) {
        print('Current user is null');
        return;
      }

      // Request location permission
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permission denied');
        // Send a message to inform the user
        final errorMessage = types.TextMessage(
          author: _currentUser!,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: '⚠️ Unable to share location: Location permission denied',
        );
        await _addMessage(errorMessage);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition();
      print('Got position: ${position.latitude}, ${position.longitude}');

      // Try to get address from coordinates
      String locationName = await _getAddressFromCoordinates(
          position.latitude, position.longitude);

      // Create Google Maps URL for navigation
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      bool staticMapSent = false;

      // Try to send static map first
      try {
        // Create Geoapify static map URL
        final staticMapUrl =
            _createStaticMapUrl(position.longitude, position.latitude);

        // Send map image message
        final imageMessage = types.ImageMessage(
          author: _currentUser!,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          name: 'Current Location',
          size: 0,
          uri: staticMapUrl,
          width: 600,
          height: 400,
          metadata: {
            'type': 'location',
            'navigationUrl': mapsUrl,
            'location': locationName,
          },
        );

        await _addMessage(imageMessage);
        staticMapSent = true;
        print('Static map image message sent successfully');
      } catch (e) {
        print('Failed to send static map: $e');
      }

      // Send location text message as fallback or additional info
      String messageText;
      if (staticMapSent) {
        messageText = '📍 My current location ($timing)\n'
            'Address: $locationName\n'
            'Tap the map above to navigate';
      } else {
        messageText = '📍 My current location ($timing)\n'
            'Address: $locationName\n'
            '📱 Live location: $mapsUrl';
      }

      final textMessage = types.TextMessage(
        author: _currentUser!,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: messageText,
        metadata: {'type': 'location', 'url': mapsUrl},
      );

      await _addMessage(textMessage);
      print('Location text message added');
    } catch (e) {
      print('Error in _shareCurrentLocation: $e');
      // Send error message to chat
      if (_currentUser != null) {
        final errorMessage = types.TextMessage(
          author: _currentUser!,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: '⚠️ Unable to share location. Please try again later.',
        );
        await _addMessage(errorMessage);
      }
    }
  }

  Future<String> _getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      final url = 'https://api.geoapify.com/v1/geocode/reverse'
          '?lat=$latitude'
          '&lon=$longitude'
          '&apiKey=$GEOAPIFY_API_KEY';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final properties = data['features'][0]['properties'];
          return _formatAddress(properties);
        }
      }
      return 'Unknown location';
    } catch (e) {
      print('Error getting address: $e');
      return 'Unknown location';
    }
  }

  String _formatAddress(Map<String, dynamic> properties) {
    List<String> addressParts = [];

    if (properties['street'] != null) addressParts.add(properties['street']);
    if (properties['city'] != null) addressParts.add(properties['city']);
    if (properties['state'] != null) addressParts.add(properties['state']);
    if (properties['country'] != null) addressParts.add(properties['country']);

    return addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'Unknown location';
  }

  Future<void> _addMessage(types.Message message) async {
    if (_currentUser != null) {
      setState(() {
        _messages.insert(0, message);
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(message.id)
          .set(message.toJson());

      print('Message successfully added to Firestore');
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
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      final file = File(filePath);

      final storageRef =
          FirebaseStorage.instance.ref().child('uploads/$fileName');
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

  Future<void> _handleMessageTap(
      BuildContext context, types.Message message) async {
    String? navigationUrl;

    if (message is types.ImageMessage &&
        message.metadata?['navigationUrl'] != null) {
      navigationUrl = message.metadata!['navigationUrl'] as String;
    } else if (message is types.TextMessage &&
        message.metadata?['url'] != null) {
      navigationUrl = message.metadata!['url'] as String;
    }

    if (navigationUrl != null) {
      final url = Uri.parse(navigationUrl);
      try {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        // Show error dialog if URL launch fails
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: const Text('Could not open map link. Please try again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create a handler function that respects the chat closed state
    void handleSendPressed(types.PartialText message) {
      if (!isChatClosed && _currentUser != null) {
        final textMessage = types.TextMessage(
          author: _currentUser!,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: message.text,
        );

        _addMessage(textMessage);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
          if (isChatClosed)
            Container(
              color: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text(
                      'This chat is closed. No new messages can be sent.'),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                if (_currentUser != null)
                  
                if (isChatClosed)
                  Positioned.fill(
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
