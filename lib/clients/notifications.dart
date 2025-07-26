import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'login_register_page.dart';

class NotificationsPage extends StatefulWidget {
  NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final User? user = Auth().currentUser;

  Future<void> signOut(BuildContext context) async {
    await Auth().signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (BuildContext context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WillPopScope(
        onWillPop: () async {
          // Handle back button press
          Navigator.pop(context);
          return true;
        },
        child: MyWebView(), // Use the MyWebView widget here
      ),
    );
  }
}

class MyWebView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        // Ensure that the type is WebUri if required by the package
        url: WebUri('https://dev-hacksmiths.pantheonsite.io/our-calender'),
      ),
    );
  }
}
