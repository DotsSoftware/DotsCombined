import 'dart:async';
import 'package:dots/clients/request_type.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quiver/async.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import 'direct_chat.dart';
import 'webview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'competency.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class SearchPage extends StatefulWidget {
  final String requestType;
  final String industryType;

  const SearchPage({
    Key? key,
    required this.requestType,
    required this.industryType,
  }) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  String? errorMessage = '';
  String? industryType;
  String? jobDescription;
  String? selectedButtonType;
  bool isLogin = true;
  bool isButtonEnabled = false;
  bool isLoading = true;
  bool isConsultantAvailable = false;
  bool showNoConsultantsText = false;
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  Map<String, dynamic>? selectedConsultant;
  Timer? _timer;
  int _secondsRemaining = 300;
  StreamSubscription<DocumentSnapshot>? _requestSubscription;
  String? requestId;
  static const apiKey = "AIzaSyDrf4oquiy8pK4eCFlCPo__WTU-6UciK8Q";
  String? activeRequestId;
  bool hasActiveRequest = false;
  String? chatId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    checkExistingRequest(userId).then((_) {
      if (!hasActiveRequest) {
        searchForConsultants(userId);
      }
    });
    _createBannerAd();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  Future<void> checkExistingRequest(String userId) async {
    try {
      QuerySnapshot activeRequests = await FirebaseFirestore.instance
          .collection('notifications')
          .where('clientId', isEqualTo: userId)
          .where('status', whereIn: ['pending', 'searching'])
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (activeRequests.docs.isNotEmpty) {
        setState(() {
          activeRequestId = activeRequests.docs.first.id;
          hasActiveRequest = true;
          isLoading = true;
          _secondsRemaining = 300;
        });
        startTimer();
        listenForRequestStatus(activeRequestId!);

        DocumentSnapshot requestDoc = activeRequests.docs.first;
        Map<String, dynamic> requestData =
            requestDoc.data() as Map<String, dynamic>;

        setState(() {
          industryType = requestData['industry_type'];
        });
      }
    } catch (e) {
      print('Error checking existing request: $e');
      setState(() {
        errorMessage = 'Error checking existing request';
      });
    }
  }

  void _createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5630199363228429/1558075005',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: ${error.message}');
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  void startTimer() {
  debugPrint('Starting timer with $_secondsRemaining seconds remaining');
  _timer?.cancel(); // Cancel any existing timer
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    debugPrint('Timer tick: $_secondsRemaining seconds remaining');
    if (!mounted) {
      debugPrint('Timer cancelled - widget not mounted');
      timer.cancel();
      return;
    }

    setState(() {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
      } else {
        debugPrint('Timer expired');
        timer.cancel();
        _handleTimerExpiration();
      }
    });
  });
}

  void _handleTimerExpiration() {
    debugPrint('Timer expired');
    if (!isConsultantAvailable) {
      setState(() {
        isLoading = false;
        showNoConsultantsText = true;
      });

      if (activeRequestId != null) {
        FirebaseFirestore.instance
            .collection('notifications')
            .doc(activeRequestId)
            .update({'status': 'expired'});
      }
    }
  }

  Future<String> getAccessToken() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "dots-b3559",
      "private_key_id": "e295a7c9d3778eaa4c6d6ed13289d437890d6111",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCxhRWSxjZam97W\n9v+QS3RzoYTq3IB95jVQFIOMJHjcc20uAWWydwMRKAO8zvnWbwXXbrlkpH82d9EC\noPE9/inxOHJeHkgR17BhNkLizXVcdTsuOFRB1jwp/iXe1sIm6MTIGNy4FNmy46YM\n8dPfqcHd5nG9Gv9DqfePYMTPQVlcNch/QOp+1jxHAWodvjduKioLFk57b6KCqxCW\ncfJBONT4rRia4lYTopdaBa4WQajRv44+s4Opy9IcyfwCWcdvB/HWs8bvy+IUbgr9\ncACNbsnUTZW6tuJ0WAvX3fjgbAPuh2rGZo7mQgjDx/sa9YeHXXQjt0/5gndC9CbE\n1SUmoqpLAgMBAAECggEAOXWnVvvbihab2Z7XeABEcE0etdqrqJTEOuh47/q6ODkQ\nZOzE2zBUiNAX7ZxdGACVtna7gY0RNDMyLxSjIXrMXqzzr+1DTKsxBzZGDh2M2GGF\nx18qPqk2ji0aWvfOnkOHtnD9uIPfN10iWVxJRUMwYj/+HsTHTUKNxBYBfkhbwVGI\nkA1HDxGcVrrJUTgWmlIH273bdUT12vzIcsujjU4sO2YDLQyMaCZH//y8QTrjiJKg\nfVqVrtIvvLF0c9iYEsLZe7ZqNVzbMZKLIPEjElT1Qh2fbDV9GP9kcLThLUW0GOgl\nkacNxXGQhcYCzdB5+8gfScbzRAQdt3AUGBVth1reCQKBgQDs16Fsu1G3ms5G/5Mi\nFD3udtnyMWQfMC7uoy/V9TxRLOxYsBayiT+PfPIQTaxA5k2g1Bz3XFIVWK0hDLO5\nAeslwrn3YwerxtLF4vss7bqiCUJmBZChhBuYp2pZudzGbNZnXBAhzZRhyOJjOBPP\ncyNRUCwY/Cxp5xV0Nw9e5iIFBwKBgQC/4Qt5m69XyZJp/loaTmoNYp2EpLH9kojV\nxQMoxqAdfOvcqZ5/rYt+P4TiZBQ4V4AnqDgEtoSB5kNWsJtN/xzqN6BKbf35qwEm\n9qjEeQZz23hDXlhIwK6YuEMJewaBKjgY+8MtsmKjNfOY7Ryvo+ubtqNNWiWmfvp4\nxRkueXWDnQKBgBUsdecFnBmhAl4AjUPXsW23PGbVmZDcOuXkuusS4JCVRo/rNixB\n7ufCENX6S7MFo90D+Y73tvLnmZrByvN4Q3B9xyhhtxbZUJCWaUQsAKppz4DVcIew\nCtOL7AsXfbBTnJti9KJBAcn4Lp0WL1c1gOvNEhQtvz68hQN9xKcERfhTAoGAfPYa\nHAu5KOn8sYzVr1YsGSWFQlJkHKkm9llFEnQw6KNnlCDfOXWTaBgD+dCFnp/VtX4H\nZYJcT6DfcAC6VBR2B09M08xIYCXvLSnshW/wNNnUu8MgqdjanFk8R1tYxBvzxsmH\ntiX7uSE00P5y9SxDD/jk50ZzSLhfdPGf0bWGQ70CgYBLx4DOWZtQoSgFPXbuxVJ7\n7Z9KRT5m9Tgbn6tm+tkESh9rtudhXAdlbqKD2qUMokHensB+o//ZlVQuNhd5AH9p\n0Vppat9apxY4lrPsWkYRT9grWqoscLeOOVY1x7sb3T5BN9FZ+7Y+7NShWKtVdx7H\nU6AwewE7uaG+JA05HWn0Yw==\n-----END PRIVATE KEY-----\n",
      "client_email": "dots-fcm-messaging@dots-b3559.iam.gserviceaccount.com",
      "client_id": "101933093859463413487",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/dots-fcm-messaging%40dots-b3559.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com",
    };
    List<String> scopes = [
      "https://www.googleapis.com/auth/userinfo.email",
      "https://www.googleapis.com/auth/firebase.database",
      "https://www.googleapis.com/auth/firebase.messaging",
    ];
    http.Client client = await auth.clientViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
      scopes,
    );
    auth.AccessCredentials credentials = await auth
        .obtainAccessCredentialsViaServiceAccount(
          auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
          scopes,
          client,
        );
    client.close();
    return credentials.accessToken.data;
  }

  Future<void> sendFCMMessage(String fcmToken, String requestId) async {
    try {
      debugPrint('Attempting to send FCM to token: $fcmToken');

      if (fcmToken.isEmpty) {
        debugPrint('Empty FCM token, skipping');
        return;
      }

      final String serverKey = await getAccessToken();
      final String fcmEndpoint =
          'https://fcm.googleapis.com/v1/projects/dots-b3559/messages:send';

      final Map<String, dynamic> message = {
        'message': {
          'token': fcmToken,
          'notification': {
            'body': 'New client request in ${widget.industryType}',
            'title': '📌 New Request Available',
          },
          'data': {
            'type': 'client_request',
            'requestId': requestId,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'industry': widget.industryType,
          },
          'android': {'priority': 'high'},
          'apns': {
            'headers': {'apns-priority': '10'},
          },
        },
      };

      debugPrint('Sending FCM payload: ${jsonEncode(message)}');

      final http.Response response = await http.post(
        Uri.parse(fcmEndpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $serverKey',
        },
        body: jsonEncode(message),
      );

      debugPrint('FCM response: ${response.statusCode} - ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('FCM failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('FCM error: $e');
      setState(() => errorMessage = 'Notification failed');
    }
  }

  Future<void> searchForConsultants(String userId) async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      QuerySnapshot clientRequestSnapshot = await FirebaseFirestore.instance
          .collection('selection')
          .doc(userId)
          .collection('requests')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (clientRequestSnapshot.docs.isEmpty) {
        setState(() {
          isLoading = false;
          showNoConsultantsText = true;
        });
        return;
      }

      final latestRequest = clientRequestSnapshot.docs.first;
      Map<String, dynamic> requestData =
          latestRequest.data() as Map<String, dynamic>;
      String clientIndustryType = requestData['industry_type'];

      QuerySnapshot consultantSnapshot = await FirebaseFirestore.instance
          .collection('consultant_register')
          .where('industry_type', isEqualTo: clientIndustryType)
          .get();

      if (consultantSnapshot.docs.isEmpty) {
        setState(() {
          isLoading = false;
          showNoConsultantsText = true;
        });
        return;
      }

      String requestId = FirebaseFirestore.instance
          .collection('notifications')
          .doc()
          .id;
      activeRequestId = requestId;

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(requestId)
          .set({
            'clientId': userId,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'searching',
            'industry_type': clientIndustryType,
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
            'paymentStatus': 'pending',
          });

      startTimer();

      for (var consultant in consultantSnapshot.docs) {
        String fcmToken = consultant['fcmToken'];
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await sendFCMMessage(fcmToken, requestId);
        }
      }

      listenForRequestStatus(requestId);
    } catch (error) {
      print("Error fetching consultants: $error");
      setState(() {
        isLoading = false;
        errorMessage = 'Error searching for consultants';
      });
    }
  }

  void listenForRequestStatus(String requestId) {
    _requestSubscription?.cancel();
    _requestSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .doc(requestId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              String status = snapshot.data()?['status'] ?? 'pending';
              if (status == 'accepted') {
                _timer?.cancel();
                displayAcceptedConsultant(
                  snapshot.data()?['acceptedConsultantId'],
                );
                setState(() {
                  hasActiveRequest = false;
                  activeRequestId = null;
                });
              }
            }
          },
          onError: (error) {
            print('Error listening for request status: $error');
            setState(() {
              errorMessage = 'Error monitoring request status';
            });
          },
        );
  }

  Future<void> displayAcceptedConsultant(String? consultantId) async {
    if (consultantId == null) return;

    try {
      DocumentSnapshot consultantDoc = await FirebaseFirestore.instance
          .collection('consultant_register')
          .doc(consultantId)
          .get();

      if (consultantDoc.exists) {
        setState(() {
          selectedConsultant = consultantDoc.data() as Map<String, dynamic>;
          isConsultantAvailable = true;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching consultant details: $e');
      setState(() {
        errorMessage = 'Error loading consultant details';
      });
    }
  }

  Widget _buildModernCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: const Color(0xFF1E3A8A), size: 24),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CircularProgressIndicator(
            strokeWidth: 10,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
            // Optional: show progress if you want
            value: 1 - (_secondsRemaining / 300),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$minutes:$seconds',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildConsultantCard() {
    if (selectedConsultant == null) return const SizedBox.shrink();
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentDate,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person,
                  size: 40,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedConsultant!['firstName'] ?? 'No Name',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Level ${selectedConsultant!['level'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Industry: ${selectedConsultant!['industry_type'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                try {
                  String consultantId = selectedConsultant!['uid'] ?? '';
                  await _createAndNavigateToChat(consultantId);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error accepting consultant: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFF0F0F0)],
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
                child: const Text(
                  'Accept Consultant',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoConsultantsWidget() {
    return Column(
      children: [
        Icon(
          Icons.sentiment_very_dissatisfied_outlined,
          size: 100,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(height: 16),
        Text(
          'Alternatively, try another search criteria.',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _createAndNavigateToChat(String consultantId) async {
    try {
      String clientId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (clientId.isEmpty || consultantId.isEmpty) {
        throw Exception('ClientId or ConsultantId is empty');
      }

      chatId = '${clientId}_$consultantId';

      await FirebaseFirestore.instance.collection('inbox').doc(chatId).set({
        'participants': [clientId, consultantId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'requestId': activeRequestId,
      }, SetOptions(merge: true));

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              WebViewPage(activeRequestId: activeRequestId, appointmentId: ''),
        ),
      );
    } catch (e) {
      print('Error creating chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create chat. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> cancelRequest() async {
    if (activeRequestId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(activeRequestId)
            .update({'status': 'cancelled'});
      } catch (e) {
        print('Error cancelling request: $e');
      }
    }
    setState(() {
      hasActiveRequest = false;
      activeRequestId = null;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Row(
                            children: [
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
                                child: Image.network(
                                  'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.error_outline,
                                        color: Color(0xFF1E3A8A),
                                        size: 30,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Connecting',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Error Message
                      if (errorMessage != null && errorMessage!.isNotEmpty)
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Main Content
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildModernCard(
                            title: isLoading
                                ? 'Searching for a Consultant'
                                : isConsultantAvailable
                                ? 'Consultant Found'
                                : 'No Consultants Available',
                            icon: Icons.person_search,
                            child: Column(
                              children: [
                                Text(
                                  isLoading
                                      ? "Please wait while we find an available consultant."
                                      : isConsultantAvailable
                                      ? 'We found a consultant for you!'
                                      : "You'll be notified once a consultant confirms.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                if (isLoading) _buildLoadingIndicator(),
                                if (isConsultantAvailable)
                                  _buildConsultantCard(),
                                if (showNoConsultantsText)
                                  _buildNoConsultantsWidget(),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Ad Banner
                      if (_isAdLoaded && _bannerAd != null)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          width: AdSize.banner.width.toDouble(),
                          height: AdSize.banner.height.toDouble(),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ),

                      // Buttons
                      if (showNoConsultantsText)
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RequestTypePage(),
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
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
                                      child: const Text(
                                        'Try Another Search Criteria',
                                        style: TextStyle(
                                          color: Color(0xFF1E3A8A),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      cancelRequest();
                                      Navigator.pop(context);
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        'Cancel Search',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _timer?.cancel();
    _requestSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}
