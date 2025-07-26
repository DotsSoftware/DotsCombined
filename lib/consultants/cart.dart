/*import 'package:flutter/material.dart';
import 'package:Benlucc/pages/login_register_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth.dart';
import 'package:Benlucc/pages/profile.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CartPage extends StatefulWidget {
  CartPage({Key? key}) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
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
}*/