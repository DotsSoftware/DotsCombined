import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'redirect.dart';
import 'search.dart';
import '../utils/theme.dart';

class WebViewPage extends StatefulWidget {
  final String? activeRequestId;
  final String appointmentId;

  const WebViewPage({
    Key? key,
    this.activeRequestId,
    required this.appointmentId,
  }) : super(key: key);

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late WebViewController _controller;
  bool _isPaymentSuccessful = false;
  bool _isLoading = true;
  Timer? _timer;
  User? _user;
  bool _hasInjectedScript = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _setUser();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            _hasInjectedScript = false;
          },
          onPageFinished: (url) async {
            setState(() => _isLoading = false);
            if (!_hasInjectedScript) {
              await _injectAmountIntoField();
              _hasInjectedScript = true;
            }
            _startCheckingPaymentStatus();
          },
          onWebResourceError: (error) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://mzansiservices.github.io/payment/'));
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

      final transactionData = {
        'userEmail': _user!.email ?? '',
        'amount': totalPrice,
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
                    'paymentAmount': totalPrice,
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

  Future<void> _injectAmountIntoField() async {
    try {
      final double totalPrice = await _fetchTotalPrice();
      final String script =
          """
        document.getElementById('payment-amount').value = $totalPrice;
        document.getElementById('payment-amount').readOnly = true;
        document.getElementById('payment-amount').disabled = true;
      """;
      await _controller.runJavaScript(script);
    } catch (e) {
      debugPrint('Error injecting amount: $e');
    }
  }

  Future<double> _fetchTotalPrice() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return double.parse(querySnapshot.docs.first['total_price']);
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching total price: $e');
      return 0.0;
    }
  }

  void _startCheckingPaymentStatus() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isPaymentSuccessful) {
        timer.cancel();
        return;
      }
      await _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final result = await _controller.runJavaScriptReturningResult("""
        (function() {
          if (document.body.innerText.includes('Your payment was successful') || 
              document.body.innerText.includes('Payment successful!')) {
            return 'success';
          }
          if (document.body.innerText.includes('Your payment was unsuccessful') || 
              document.body.innerText.includes('Failed')) {
            return 'failed';
          }
          return 'pending';
        })();
      """);

      if (result == 'success') {
        _handlePaymentSuccess();
      } else if (result == 'failed') {
        _handlePaymentFailure();
      }
    } catch (e) {
      debugPrint('Error checking payment status: $e');
    }
  }

  Future<void> _handlePaymentSuccess() async {
    if (_isPaymentSuccessful) return;

    setState(() => _isPaymentSuccessful = true);
    _timer?.cancel();

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(widget.appointmentId)
        .update({
          'paymentStatus': 'Paid',
          'paymentTimestamp': FieldValue.serverTimestamp(),
        });

    await _storeTransactionData('Paid');
  }

  Future<void> _handlePaymentFailure() async {
    _timer?.cancel();

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(widget.appointmentId)
        .update({
          'paymentStatus': 'Failed',
          'paymentTimestamp': FieldValue.serverTimestamp(),
        });

    await _storeTransactionData('Failed');
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
      ],
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
                child: Row(
                  children: [
                    // App bar image
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
                      child: CachedNetworkImage(
                        imageUrl:
                            'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
                        fit: BoxFit.contain,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF1E3A8A),
                              ),
                            ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.error_outline,
                          color: Color(0xFF1E3A8A),
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Payment',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RedirectPage()),
                      ),
                    ),
                    if (_isPaymentSuccessful)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RedirectPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Continue',
                            style: TextStyle(color: Color(0xFF1E3A8A)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // WebView
              Expanded(
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
                    child: _buildWebView(),
                  ),
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
