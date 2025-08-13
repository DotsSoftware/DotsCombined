import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'redirect.dart'; // Import RedirectPage

class YocoPaymentPage extends StatefulWidget {
  final double amount;
  final String currency;
  final String description;
  final String customerReference;

  const YocoPaymentPage({
    Key? key,
    required this.amount,
    required this.currency,
    required this.description,
    required this.customerReference,
  }) : super(key: key);

  @override
  _YocoPaymentPageState createState() => _YocoPaymentPageState();
}

class _YocoPaymentPageState extends State<YocoPaymentPage> {
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  String? _checkoutId; // Store checkout ID for status checking
  User? _user;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    dotenv.load(fileName: ".env").catchError((e) {
      setState(() {
        _errorMessage = 'Failed to load .env file: $e';
      });
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final apiKey = dotenv.env['YOCO_SECRET_KEY'];
      if (apiKey == null) {
        throw Exception('YOCO_SECRET_KEY not found in .env');
      }

      // Create checkout
      final checkoutResponse = await http.post(
        Uri.parse('https://payments.yoco.com/api/checkouts'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (widget.amount * 100).toInt(), // Convert to cents
          'currency': widget.currency,
          'description': widget.description,
          'externalId': widget.customerReference,
          'successUrl':
              'myapp://payment/success', // Configure your app's success redirect URL
          'cancelUrl':
              'myapp://payment/cancel', // Configure your app's cancel redirect URL
          'failureUrl':
              'myapp://payment/failure', // Configure your app's failure redirect URL
        }),
      );

      if (checkoutResponse.statusCode == 201) {
        final responseData = jsonDecode(checkoutResponse.body);
        final checkoutUrl = responseData['redirectUrl'];
        _checkoutId =
            responseData['id']; // Store checkout ID for status checking

        // Launch checkout URL
        await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        );

        // Start polling for payment status
        _startCheckingPaymentStatus();
      } else {
        throw Exception('Failed to create checkout: ${checkoutResponse.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Payment initiation failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _startCheckingPaymentStatus() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_successMessage.isNotEmpty || _errorMessage.isNotEmpty) {
        timer.cancel();
        return;
      }
      await _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final apiKey = dotenv.env['YOCO_SECRET_KEY'];
      if (apiKey == null || _checkoutId == null) {
        throw Exception('API key or checkout ID missing');
      }

      final response = await http.get(
        Uri.parse('https://payments.yoco.com/api/checkouts/$_checkoutId'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (response.statusCode == 200) {
        final checkoutData = jsonDecode(response.body);
        final status = checkoutData['status'];

        if (status == 'fulfilled') {
          await _handlePaymentSuccess();
        } else if (status == 'cancelled' || status == 'expired') {
          await _handlePaymentFailure(status);
        }
      } else {
        throw Exception('Failed to check payment status: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking payment status: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePaymentSuccess() async {
    setState(() {
      _successMessage = 'Payment successful!';
      _isLoading = false;
    });

    await _storeTransactionData('Paid');

    // Navigate to RedirectPage
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RedirectPage()),
    );
  }

  Future<void> _handlePaymentFailure(String status) async {
    setState(() {
      _errorMessage = 'Payment $status.';
      _isLoading = false;
    });

    await _storeTransactionData(
      status == 'cancelled' ? 'Cancelled' : 'Expired',
    );
  }

  Future<void> _storeTransactionData(String status) async {
    if (_user != null) {
      final transactionData = {
        'userEmail': _user!.email ?? '',
        'amount': widget.amount,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Update notifications collection
      await FirebaseFirestore.instance
          .collection('notifications')
          .where('clientId', isEqualTo: _user!.uid)
          .where('status', whereIn: ['accepted', 'searching', 'pending'])
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get()
          .then((querySnapshot) async {
            if (querySnapshot.docs.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(querySnapshot.docs.first.id)
                  .update({
                    'paymentStatus': status,
                    'paymentTimestamp': FieldValue.serverTimestamp(),
                    'paymentAmount': widget.amount,
                    'transactionDetails': transactionData,
                  });
            }
          });

      // Update accepted collection
      await FirebaseFirestore.instance
          .collection('accepted')
          .where('client', isEqualTo: _user!.email)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get()
          .then((querySnapshot) async {
            if (querySnapshot.docs.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('accepted')
                  .doc(querySnapshot.docs.first.id)
                  .update({
                    'transactions': FieldValue.arrayUnion([transactionData]),
                    'paymentStatus': status,
                  });
            }
          });

      // Add to transactions collection
      await FirebaseFirestore.instance
          .collection('transactions')
          .add(transactionData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment with Yoco'),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Summary
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount:'),
                        Text(
                          '${widget.currency} ${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Description:'),
                        Text(widget.description),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reference:'),
                        Text(widget.customerReference),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Error and Success Messages
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            if (_successMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _successMessage,
                  style: const TextStyle(color: Colors.green),
                ),
              ),

            // Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'PAY NOW',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Alternative Payment Methods
            const Center(
              child: Text('OR PAY WITH', style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Image.asset('assets/yoco_logo.png'),
                  onPressed: () {
                    // Handle Yoco payment method
                  },
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.qr_code, size: 40),
                  onPressed: () {
                    // Handle QR code payment
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
