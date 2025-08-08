import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'redirect.dart';
import 'search.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient

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

class _WebViewPageState extends State<WebViewPage>
    with TickerProviderStateMixin {
  late WebViewController _controller;
  bool _isPaymentSuccessful = false;
  Timer? _timer;
  User? _user;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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

    preloadWebView();
    _setUser();
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

    _colorAnimation =
        ColorTween(begin: const Color(0xFF1E3A8A), end: Colors.red).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
          ),
        );

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
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

             await FirebaseFirestore.instance
           .collection('notifications')
           .where('clientId', isEqualTo: _user!.uid)
           .where('status', whereIn: ['accepted','searching','pending'])
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

      await FirebaseFirestore.instance
          .collection('transactions')
          .add(transactionData);
    }
  }

  void preloadWebView() {
    _controller.loadRequest(Uri.parse('https://paystack.com/pay/dots'));
  }

  Future<void> _injectAmountIntoField() async {
    final double totalPrice = await _fetchTotalPrice();

    final String script =
        """
      document.getElementById('payment-amount').value = $totalPrice;
      document.getElementById('payment-amount').readOnly = true;
      document.getElementById('payment-amount').disabled = true;
    """;

    _controller.runJavaScript(script);
  }

  Future<double> _fetchTotalPrice() async {
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
    return 0.0;
  }

  Future<void> _startCheckingPaymentStatus() async {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
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

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.appointmentId)
          .update({
            'paymentStatus': 'Paid',
            'paymentTimestamp': FieldValue.serverTimestamp(),
          });

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

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.appointmentId)
          .update({
            'paymentStatus': 'Failed',
            'paymentTimestamp': FieldValue.serverTimestamp(),
          });

      await _storeTransactionData('Failed');
    }
  }

  Widget _title() {
    return const Text(
      'Payment',
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
      child: CachedNetworkImage(
        imageUrl:
            'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
        fit: BoxFit.contain,
        placeholder: (context, url) => const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
        ),
        errorWidget: (context, url, error) =>
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
                        if (_isPaymentSuccessful)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RedirectPage(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedBuilder(
                                  animation: _colorAnimation,
                                  builder: (context, _) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white,
                                            Color(0xFFF0F0F0),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.arrow_forward,
                                            color: _colorAnimation.value,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Continue',
                                            style: TextStyle(
                                              color: _colorAnimation.value,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // WebView
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
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
                        child: WebViewWidget(controller: _controller),
                      ),
                    ),
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
