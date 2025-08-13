import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'redirect.dart'; // Import RedirectPage
import '../utils/theme.dart';

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

class _YocoPaymentPageState extends State<YocoPaymentPage>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  String? _checkoutId;
  User? _user;
  Timer? _statusTimer;
  double _finalAmount = 0.0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _fetchCorrectAmount();
    _initAnimations();
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

    _animationController.forward();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchCorrectAmount() async {
    try {
      final transactionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user?.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (transactionSnapshot.docs.isNotEmpty) {
        final transactionData = transactionSnapshot.docs.first.data();
        if (transactionData.containsKey('total_price')) {
          setState(() {
            _finalAmount =
                double.parse(transactionData['total_price'].toString());
          });
          return;
        }
      }

      final appointmentSnapshot = await FirebaseFirestore.instance
          .collection('selection')
          .doc(_user?.uid)
          .collection('appointments')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (appointmentSnapshot.docs.isNotEmpty) {
        final appointmentData = appointmentSnapshot.docs.first.data();
        if (appointmentData.containsKey('consultantFee')) {
          setState(() {
            _finalAmount =
                double.parse(appointmentData['consultantFee'].toString());
          });
          return;
        }
      }

      setState(() {
        _finalAmount = widget.amount;
      });
    } catch (e) {
      print('Error fetching correct amount: $e');
      setState(() {
        _finalAmount = widget.amount;
        _errorMessage = 'Error fetching payment amount: $e';
      });
    }
  }

  Future<void> _processPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");
      final yocoApiKey = dotenv.env['YOCO_API_KEY'];
      final yocoApiUrl = dotenv.env['YOCO_API_URL'];

      if (yocoApiKey == null || yocoApiUrl == null) {
        throw Exception('Yoco API credentials not configured');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $yocoApiKey',
      };

      final body = jsonEncode({
        'amount': (_finalAmount * 100).toInt(),
        'currency': widget.currency,
        'description': widget.description,
        'externalId': widget.customerReference,
        'successUrl': 'myapp://payment/success',
        'cancelUrl': 'myapp://payment/cancel',
        'failureUrl': 'myapp://payment/failure',
      });

      final response = await http.post(
        Uri.parse('$yocoApiUrl/checkouts'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data.containsKey('redirectUrl') && data.containsKey('id')) {
          final checkoutUrl = data['redirectUrl'];
          _checkoutId = data['id'];

          await launchUrl(
            Uri.parse(checkoutUrl),
            mode: LaunchMode.externalApplication,
          );

          _startCheckingPaymentStatus();
        } else {
          throw Exception('Invalid response from Yoco API');
        }
      } else {
        throw Exception('Failed to create checkout: ${response.body}');
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
      if (_checkoutId == null) {
        throw Exception('Checkout ID missing');
      }

      // Load environment variables
      await dotenv.load(fileName: ".env");
      final yocoApiKey = dotenv.env['YOCO_API_KEY'];
      final yocoApiUrl = dotenv.env['YOCO_API_URL'];

      if (yocoApiKey == null || yocoApiUrl == null) {
        throw Exception('Yoco API credentials not configured');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $yocoApiKey',
      };

      final response = await http.get(
        Uri.parse('$yocoApiUrl/checkouts/$_checkoutId'),
        headers: headers,
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
        throw Exception('Failed to get checkout status: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking payment status: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePaymentSuccess() async {
    _statusTimer?.cancel();
    setState(() {
      _successMessage = 'Payment successful!';
      _isLoading = false;
    });

    await _storeTransactionData('Paid');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RedirectPage()),
    );
  }

  Future<void> _handlePaymentFailure(String status) async {
    _statusTimer?.cancel();
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

      await FirebaseFirestore.instance.collection('transactions').add(
          transactionData);
    }
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
      child: Image.network(
        'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.error_outline,
          color: Color(0xFF1E3A8A),
          size: 30,
        ),
      ),
    );
  }

  Widget _title() {
    return const Text(
      'Payment with Yoco',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
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
                        Expanded(child: _title()),
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
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
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
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Amount:',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${widget.currency} ${_finalAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Description:',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          widget.description,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Reference:',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          widget.customerReference,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_errorMessage.isNotEmpty)
                          SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.red.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_successMessage.isNotEmpty)
                          SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.green.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _successMessage,
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isLoading ? null : _processPayment,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? const CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          )
                                        : const Text(
                                            'PAY NOW',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                Text(
                                  'OR PAY WITH',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          // Note: This button is not fully functional in this example.
                                          // Its logic would also need to be handled by a secure backend.
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.3)),
                                          ),
                                          child: Image.asset(
                                            'assets/yoco_logo.png',
                                            width: 40,
                                            height: 40,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                              Icons.error_outline,
                                              color: Colors.red,
                                              size: 40,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          // Handle QR code payment if supported by Yoco
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.3)),
                                          ),
                                          child: const Icon(
                                            Icons.qr_code,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}