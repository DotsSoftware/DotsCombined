import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'redirect.dart';
import 'search.dart';

class WebViewPage extends StatefulWidget {
  final String? activeRequestId;
  final String appointmentId;

  WebViewPage(
      {this.activeRequestId,
      required this.appointmentId // Corrected constructor
      });

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late WebViewController _controller;
  bool _isPaymentSuccessful = false;
  Timer? _timer;
  User? _user;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _injectAmountIntoField();
            _startCheckingPaymentStatus();
          },
        ),
      );

    // Preload the WebView
    preloadWebView();
    _setUser();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _setUser() async {
    _user = FirebaseAuth.instance.currentUser;
  }

  Future<void> _storeTransactionData(String status) async {
    if (_user != null) {
      final totalPrice = await _fetchTotalPrice();

      // Store transaction in 'transactions' collection
      final transactionData = {
        'userEmail': _user!.email ?? '',
        'amount': totalPrice,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // First, update the notifications collection
      await FirebaseFirestore.instance
          .collection('notifications')
          .where('clientId', isEqualTo: _user!.uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get()
          .then((querySnapshot) async {
        if (querySnapshot.docs.isNotEmpty) {
          final notificationDoc = querySnapshot.docs.first;
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(notificationDoc.id)
              .update({
            'paymentStatus': status,
            'paymentTimestamp': FieldValue.serverTimestamp(),
            'paymentAmount': totalPrice,
            'transactionDetails': transactionData,
          });
        }
      });

      // Then update the accepted collection
      await FirebaseFirestore.instance
          .collection('accepted')
          .where('client', isEqualTo: _user!.email)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get()
          .then((querySnapshot) async {
        if (querySnapshot.docs.isNotEmpty) {
          final acceptedDoc = querySnapshot.docs.first;
          await FirebaseFirestore.instance
              .collection('accepted')
              .doc(acceptedDoc.id)
              .update({
            'transactions': FieldValue.arrayUnion([transactionData]),
            'paymentStatus': status,
          });
        }
      });

      // Finally store in transactions collection for record keeping
      await FirebaseFirestore.instance
          .collection('transactions')
          .add(transactionData);
    }
  }

  void preloadWebView() {
    // Load the URL asynchronously to start fetching early
    _controller.loadRequest(Uri.parse('https://paystack.com/pay/dots'));
  }

  Future<void> _injectAmountIntoField() async {
    final double totalPrice = await _fetchTotalPrice();

    final String script = """
      document.getElementById('payment-amount').value = $totalPrice;
      document.getElementById('payment-amount').readOnly = true;
      document.getElementById('payment-amount').disabled = true;
    """;

    _controller.runJavaScript(script);
  }

  Future<double> _fetchTotalPrice() async {
    // Fetch the latest transaction document
    final transactionQuerySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (transactionQuerySnapshot.docs.isNotEmpty) {
      final transactionDoc = transactionQuerySnapshot.docs.first;
      return double.parse(transactionDoc['total_price']);
    }
    return 0.0; // Default value if no transaction is found
  }

  Future<void> _startCheckingPaymentStatus() async {
    _timer = Timer.periodic(Duration(seconds: 2), (timer) {
      _checkPaymentSuccess();
      _checkPaymentFailed();
    });
  }

  Future<void> _checkPaymentSuccess() async {
    final String script = """
      (function() {
        return document.body.innerText.includes('Your payment was successful') || 
               document.body.innerText.includes('Payment successful!');
      })();
    """;

    final result = await _controller.runJavaScriptReturningResult(script);

    if (result == true) {
      setState(() {
        _isPaymentSuccessful = true;
      });
      _timer?.cancel();

      // Update payment status in notifications collection using the appointment ID
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.appointmentId)
          .update({
        'paymentStatus': 'Paid',
        'paymentTimestamp': FieldValue.serverTimestamp(),
      });

      // Store complete transaction data across all collections
      await _storeTransactionData('Paid');
    }
  }

  Future<void> _checkPaymentFailed() async {
    final String script = """
      (function() {
        return document.body.innerText.includes('Your payment was unsuccessful') || 
               document.body.innerText.includes('Failed');
      })();
    """;

    final result = await _controller.runJavaScriptReturningResult(script);

    if (result == true) {
      _timer?.cancel();

      // Update payment status in notifications collection using the appointment ID
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.appointmentId)
          .update({
        'paymentStatus': 'Failed',
        'paymentTimestamp': FieldValue.serverTimestamp(),
      });

      // Store complete transaction data across all collections
      await _storeTransactionData('Failed');
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

  Widget _appBarImage() {
    return CachedNetworkImage(
      imageUrl:
          'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
      height: 55,
      width: 55,
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) => const Text('Image not found'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            _appBarImage(),
            const SizedBox(width: 10),
            _title(),
            const Spacer(),
            if (_isPaymentSuccessful)
              Column(
                children: [
                  TweenAnimationBuilder(
                    tween: ColorTween(
                        begin: Color.fromARGB(225, 0, 74, 173),
                        end: Colors.red),
                    duration: Duration(seconds: 1),
                    builder: (context, Color? color, _) {
                      return IconButton(
                        icon: Icon(Icons.arrow_forward),
                        color: color,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => RedirectPage()),
                          );
                        },
                      );
                    },
                    onEnd: () {
                      setState(
                          () {}); // Restart the animation to keep it flashing
                    },
                  ),
                  const SizedBox(height: 4), // Space between the icon and text
                  const Text(
                    'Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(225, 0, 74, 173),
                      fontSize: 12, // Adjust text size as needed
                    ),
                  ),
                ],
              ),
          ],
        ),
        toolbarHeight: 70,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
