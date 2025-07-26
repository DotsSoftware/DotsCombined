import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';

class ChatPage extends StatefulWidget {
  final String chatRoomId;
  final Map<String, dynamic> userMap;

  const ChatPage({
    required this.chatRoomId,
    required this.userMap,
    Key? key,
    required String requestId,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<types.Message> _messages = [];
  types.User? _user;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _listenForMessages();
  }

  Future<void> _initializeUser() async {
    User? firebaseUser = _auth.currentUser;

    setState(() {
      _user = types.User(
        id: firebaseUser!.uid,
        firstName: firebaseUser.displayName ?? "Anon",
      );
    });
  }

  void _listenForMessages() {
    _firestore
        .collection('chatRoom')
        .doc(widget.chatRoomId)
        .collection('chats')
        .orderBy('time', descending: true)
        .snapshots()
        .listen((snapshot) {
      final messages = snapshot.docs
          .map((doc) =>
              types.Message.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      setState(() {
        _messages = messages;
      });
    });
  }

  void _handleSendPressed(types.PartialText message) {
    if (_user != null) {
      final textMessage = types.TextMessage(
        author: _user!,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: message.text,
      );

      _addMessage(textMessage);
    }
  }

  void _addMessage(types.Message message) async {
    setState(() {
      _messages.insert(0, message);
    });

    await _firestore
        .collection('chatRoom')
        .doc(widget.chatRoomId)
        .collection('chats')
        .doc(message.id)
        .set(message.toJson());
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
      final ref = FirebaseStorage.instance.ref().child('uploads/$fileName');

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      if (_user != null) {
        final message = types.FileMessage(
          author: _user!,
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
      final ref = FirebaseStorage.instance.ref().child('uploads/$fileName');

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);

      if (_user != null) {
        final message = types.ImageMessage(
          author: _user!,
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

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        final index =
            _messages.indexWhere((element) => element.id == message.id);
        final updatedMessage = (_messages[index] as types.FileMessage).copyWith(
          isLoading: true,
        );

        setState(() {
          _messages[index] = updatedMessage;
        });

        final client = http.Client();
        final request = await client.get(Uri.parse(message.uri));
        final bytes = request.bodyBytes;
        final documentsDir = (await getApplicationDocumentsDirectory()).path;
        localPath = '$documentsDir/${message.name}';

        if (!File(localPath).existsSync()) {
          final file = File(localPath);
          await file.writeAsBytes(bytes);
        }

        final updatedMessageLoaded =
            (_messages[index] as types.FileMessage).copyWith(
          isLoading: false,
          uri: localPath,
        );

        setState(() {
          _messages[index] = updatedMessageLoaded;
        });
      }

      await OpenFilex.open(localPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userMap['firstName']),
      ),
          
    );
  }
}
