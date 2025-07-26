import 'package:dots/clients/firebase_auth_service.dart';
import 'package:dots/clients/webview.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class WaitingPage extends StatefulWidget {
  final String consultantToken; // FCM Token of the consultant

  const WaitingPage({Key? key, required this.consultantToken})
      : super(key: key);

  @override
  _WaitingPageState createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage>
    with TickerProviderStateMixin {
  bool isButtonEnabled = false; // Disable the button initially
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    sendNotificationToConsultant();

    // Listen for notification responses
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['status'] == 'accepted') {
        setState(() {
          isButtonEnabled =
              true; // Enable the button when the consultant accepts
        });
      }
    });

    // Create ripple animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Send notification to consultant
  Future<void> sendNotificationToConsultant() async {
    final FirebaseAuthService authService = FirebaseAuthService();
    String accessToken = await authService.getAccessToken();
    String url =
        'https://fcm.googleapis.com/v1/projects/dots-b3559/messages:send';

    final message = {
      "message": {
        "token": widget.consultantToken, // Consultant's FCM token
        "notification": {
          "title": "New Request",
          "body": "You have a new request from a client.",
        },
        "data": {
          "status": "pending",
        },
      }
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print("Notification sent to consultant.");
    } else {
      print("Failed to send notification: ${response.body}");
    }
  }

  Widget _title() {
    return const Text(
      'DOTS',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Color.fromARGB(225, 0, 74, 173),
        fontFamily: 'Quicksand',
      ),
    );
  }

  Widget _firebaseImage() {
    return Image.network(
      'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
      height: 55,
      width: 55,
      errorBuilder:
          (BuildContext context, Object exception, StackTrace? stackTrace) {
        return const Text('Image not found');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const SizedBox(width: 10),
            _firebaseImage(),
            const SizedBox(width: 10),
            _title(),
          ],
        ),
        toolbarHeight: 72,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Notification sent to Consultant, waiting for response",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            RippleAnimation(controller: _controller), // Custom ripple animation
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: isButtonEnabled
                  ? () {
                      // Navigate to the next page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => WebViewPage(
                                  appointmentId: '',
                                )), // Replace with your next page
                      );
                    }
                  : null, // Disable button if not enabled
              style: ElevatedButton.styleFrom(
                backgroundColor: isButtonEnabled
                    ? Color.fromARGB(225, 0, 74, 173)
                    : Colors.grey, // Change button color
              ),
              child: Text("Proceed to Payment"),
            ),
          ],
        ),
      ),
    );
  }
}

class RippleAnimation extends StatelessWidget {
  final AnimationController controller;

  const RippleAnimation({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildRipple(0.0, 100, controller),
              _buildRipple(0.2, 150, controller),
              _buildRipple(0.4, 200, controller),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRipple(
      double delay, double size, AnimationController controller) {
    return ScaleTransition(
      scale: Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        ),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.fromARGB(225, 0, 74, 173).withOpacity(1.0 - delay),
        ),
      ),
    );
  }
}
