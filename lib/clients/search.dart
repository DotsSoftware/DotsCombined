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
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
          if (!isConsultantAvailable) {
            setState(() {
              isLoading = false;
              showNoConsultantsText = true;
            });
            // Don't clear the request - keep it active in Firestore
            if (activeRequestId != null) {
              FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(activeRequestId)
                  .update({'status': 'pending'});
            }
          }
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
      "private_key_id": "9828916518aae6ee63dee0f5efb5bf1b990ddfba",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC4gJhJcOQnDkvc\nP+RiDdSl7hYl3KBDlDo/hp1RyoxzKLqzwrqSRBEMFfZN7WIEUZJV/2whdOI7oEFt\n2Z5O+JeDqNblMw5WMTjlGHkDR3ZcDHrv9oIGjF4NXtkT36esXNjVbEUKbwLlD24K\nEpxZy6/zbXwiFieIPvzlZmd5Xo7fKxYqmetYiirOc8X5wSk/bLuKADGEOyHyamd/\n0HgBVsoVkoOTF2verBLdvib5UTvgnM2ov5xb/mnbbeAGlZALkieeSW1j4spGO4Sk\nwGO/6sFG2s91UTO113gi8YwHOAP2ae8ZMnTJle8seVg2iQebzLH+/Zj69hpIIKsQ\nDSLUxhzlAgMBAAECggEADHgqcqo1zTru3xWVXJglM0quRgRNc4vIzQLOzpiTGfRa\ne+ww+lIt2cSBNz6QJY0SyAuhdfhlktSPn3o59AniiZQnY+mpsiMU/ozDHvjdM7bn\nNyEQpBsn/xzWLHzs4t4KjJAK8XvTtQHwNK+R0BLPUzMm1NHs/Y0OP/3GCAKfQs9T\n0VhUHtq/BQZksAUU2ANAUbXpnoY7rBnPCwiL8kSTAptxQ6dbSskuCxLtqSZkqSxo\n4EsOfOUcB6WsV8y3+SutIAvPsWaDNxzUrzfGXfIRXdwO6+guRyN22OonLylfwddi\nhvGHZJlf+jUqcPOu/sSX6z2p0XZR13HwsXn4v6M4YQKBgQD1kl3mxX8hB5ra/uqL\njLbw9+000uMMiA158kllHaW87uRmlDfEFiQnj5FFhb0sXSPlvPm37f2ifnNlsa6a\ns6D63XZmAdWvTlGbzxK5NTlmKNvxSlN7G4L7/7M4wKc5JxGHrB7yV1T1XkdMtElH\nQx62iKmU5gnXBPAXYb8b1Da24QKBgQDAVlYzwWs/43ZRPkXIejFqZcmuQCfw+9OB\nfrKGOIXYlpCHQDxZ9w9DGYX5/xlAa8G6YRO+bjqF3RqdKAEcRs+XfhYTHj4j0ZOo\niDP7nnpQh6saVlVYlSSkziajE3C0bgjs62dw7R2zTVPVX+GSvzUaLUC4+x9sygea\n1pDUD85ahQKBgFGgTUYf75nzBS41/ZBVPZnrTxV347COqKwYNP0/VY/veEwAiGjN\nU0czGX6abb8JVp1Oq1LP8LbKgWEUJo2Vl7TLWEef5H9Y8RdxRS/62RF0E2eo5QbO\npkNNQy1iHDOLIPCP7dlv3fWRWPHOG21sihDybCvqKusl4QhknTmK2IUBAoGAXQAi\nNGpc+op45nXO9k4nYMQRDgGVjo+lyKLDneTsyzqabdugkvvEVHSd9LDlu+Gezgks\nq9LO13V+7eivCMYwkJb2A46HC3jGBiK9x/fsOs4u7NA7+lY7XrkTs5ytzYC7Lhvx\na4gr6UwFslHnV7a+7YZeGlPK8SaLINKJOxDdfaUCgYAUZIxpgvhgfY+NtgysDcGc\nxewumxc7Ba0kVyMFiYsI5DJxBDqkJ9L3aayunf8OvAj7sHzwY6QXjwE8PfEjZMYV\nhGZ25qU1Bvew7B+/Ic/pdvQ077qwANyxduife3ImF9uuXZPNG7RNn0yukXO4iElf\ne6CJGLr6YxGO2/6GKCPa7g==\n-----END PRIVATE KEY-----\n",
      "client_email":
          "firebase-adminsdk-ecgab@dots-b3559.iam.gserviceaccount.com",
      "client_id": "106002613230535720514",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-ecgab%40dots-b3559.iam.gserviceaccount.com",
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
      // Save request details to Firestore

      await FirebaseFirestore.instance
          .collection('active_requests')
          .doc(requestId)
          .set({
            'clientId': FirebaseAuth.instance.currentUser?.uid,

            'timestamp': FieldValue.serverTimestamp(),

            'status': 'pending',

            // Add other relevant request details
          });

      await FirebaseFirestore.instance.collection('active_requests').add({
        'consultantId': fcmToken,
        'requestId': requestId,
        'title': 'New Client Request',
        'body': 'You have a new client request!',
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final String serverKey = await getAccessToken(); // Get your server key

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
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'high_importance_channel',
              'priority': 'high',
              'default_sound': true,
              'default_vibrate_timings': true,
            },
          },
          'apns': {
            'headers': {'apns-priority': '10'},
            'payload': {
              'aps': {'sound': 'default', 'badge': 1},
            },
          },
        },
      };

      final http.Response response = await http.post(
        Uri.parse(fcmEndpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $serverKey',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print('FCM message sent successfully to $fcmToken');
      } else {
        print('Failed to send FCM message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending FCM message or saving to Firestore: $e');
    }
  }

  Future<void> searchForConsultants(String userId) async {
    try {
      // Fetch the latest client request
      QuerySnapshot clientRequestSnapshot = await FirebaseFirestore.instance
          .collection('selection')
          .doc(userId)
          .collection('requests')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (clientRequestSnapshot.docs.isNotEmpty) {
        final latestRequest = clientRequestSnapshot.docs.first;
        Map<String, dynamic> requestData =
            latestRequest.data() as Map<String, dynamic>;
        String clientIndustryType = requestData['industry_type'];

        // Fetch the latest appointment details
        QuerySnapshot appointmentSnapshot = await FirebaseFirestore.instance
            .collection('selection')
            .doc(userId)
            .collection('appointments')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        Map<String, dynamic> appointmentData = {};
        if (appointmentSnapshot.docs.isNotEmpty) {
          appointmentData =
              appointmentSnapshot.docs.first.data() as Map<String, dynamic>;
        }

        // Fetch consultants based on industry type
        QuerySnapshot consultantSnapshot = await FirebaseFirestore.instance
            .collection('consultant_register')
            .where('industry_type', isEqualTo: clientIndustryType)
            .get();

        if (consultantSnapshot.docs.isNotEmpty) {
          // Save notification request data
          String requestId = FirebaseFirestore.instance
              .collection('notifications')
              .doc()
              .id;
          activeRequestId = requestId; // Store the request ID

          // Save notification request data with additional fields
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(requestId)
              .set({
                'clientId': userId,
                'timestamp': FieldValue.serverTimestamp(),
                'status': 'searching',
                'industry_type': clientIndustryType,
                'jobDate': appointmentData['jobDate'] ?? '',
                'jobTime': appointmentData['jobTime'] ?? '',
                'siteLocation': appointmentData['siteLocation'] ?? '',
                'jobDescription': appointmentData['jobDescription'] ?? '',
                'expiresAt': FieldValue.serverTimestamp()
                    .toString(), // Add expiration timestamp
                'paymentStatus': 'pending', // Add payment status field
              });

          // Modified timer logic
          startTimer();

          // Send FCM message to each consultant
          for (var consultant in consultantSnapshot.docs) {
            String fcmToken = consultant['fcmToken'];
            await sendFCMMessage(fcmToken, requestId);
          }

          // Listen for request status changes
          listenForRequestStatus(requestId);
        }
      }
    } catch (error) {
      print("Error fetching consultants: $error");
    }
  }

  void listenForRequestStatus(String requestId) {
    _requestSubscription?.cancel();
    _requestSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .doc(requestId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            String status = snapshot.data()?['status'];
            if (status == 'accepted') {
              _timer?.cancel();
              displayAcceptedConsultant(
                snapshot.data()?['acceptedConsultantId'],
              );

              // Clear the active request
              setState(() {
                hasActiveRequest = false;
                activeRequestId = null;
              });
            }
          }
        });
  }

  Future<void> displayAcceptedConsultant(String consultantId) async {
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
