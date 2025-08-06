import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'consultant_dashboard.dart';
import 'consultant_register.dart';
import 'industry_selection.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'password.dart';
import '../utils/theme.dart'; // Assuming this contains the appGradient
import '../utils/notification_service.dart';

class ConsultantLoginPage extends StatefulWidget {
  const ConsultantLoginPage({Key? key}) : super(key: key);

  @override
  _ConsultantLoginPageState createState() => _ConsultantLoginPageState();
}

class _ConsultantLoginPageState extends State<ConsultantLoginPage>
    with TickerProviderStateMixin {
  String? errorMessage = '';
  bool showPassword = false;
  bool isLoading = false;

  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  // Add these to your state class
  String? _authToken;
  DateTime? _tokenExpiry;
  Timer? _tokenRefreshTimer;

  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!(await _isTokenValid())) {
        await _generateNewToken();
        debugPrint('Token refreshed at ${DateTime.now()}');
      }
    });
  }

  void setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Convert Map<String, dynamic> to Map<String, String?>
       final Map<String, String?> payload = AppNotificationService.convertPayload(message.data);

      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'high_importance_channel',
          title: message.notification?.title ?? 'New Notification',
          body: message.notification?.body ?? 'You have a new message',
          payload: payload, // Use the converted payload
        ),
      );
    });
  }

  Future<void> _generateNewToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final tokenResult = await user.getIdTokenResult();
        setState(() {
          _authToken = tokenResult.token;
          _tokenExpiry = tokenResult.expirationTime;
        });
      }
    } catch (e) {
      debugPrint('Token generation error: $e');
    }
  }

  Future<bool> _isTokenValid() async {
    if (_authToken == null || _tokenExpiry == null) return false;

    final now = DateTime.now();
    final bufferTime = const Duration(
      minutes: 5,
    ); // Refresh 5 mins before expiry

    return _tokenExpiry!.subtract(bufferTime).isAfter(now);
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startTokenRefreshTimer();
    setupFCMListeners();
    FirebaseMessaging.instance.onTokenRefresh.listen((newFcmToken) async {
      debugPrint('FCM token refreshed: $newFcmToken');
      await _updateFCMToken();
    });
  }

  Future<void> _requestNotificationPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  Future<void> signInWithEmailAndPassword() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _controllerEmail.text.trim(),
            password: _controllerPassword.text.trim(),
          );

      // Generate and verify token
      await _generateNewToken();
      if (_authToken == null) {
        throw FirebaseAuthException(
          code: 'token-generation-failed',
          message: 'Could not generate authentication token',
        );
      }

      // Add this - Update FCM token after successful auth
      await _updateFCMToken();
      await _requestNotificationPermissions();

      if (await _isTokenValid()) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ConsultantDashboardPage()),
        );
      } else {
        setState(() {
          errorMessage = 'Session expired. Please login again.';
          isLoading = false;
        });
        await FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateFCMToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && _authToken != null) {
        await FirebaseFirestore.instance
            .collection('consultants')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .update({
              'fcmToken': fcmToken,
              'tokenExpiry': _tokenExpiry,
              'lastActive': FieldValue.serverTimestamp(),
            });
        debugPrint('FCM token updated successfully');
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  Widget _title() {
    return const Text(
      'DOTS',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontFamily: 'Quicksand',
        fontSize: 32,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _appBarImage() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Image.network(
          'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
          fit: BoxFit.contain,
          errorBuilder:
              (BuildContext context, Object exception, StackTrace? stackTrace) {
                return const Text(
                  'Image not found',
                  style: TextStyle(color: Colors.white),
                );
              },
        ),
      ),
    );
  }

  Widget _welcomeText() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Image.asset(
                        'assets/icons/icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 48),
          Text(
            'Welcome Back!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Quicksand',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please enter your details',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w300,
              fontFamily: 'Quicksand',
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryField(
    String title,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: TextField(
          controller: controller,
          obscureText: isPassword && !showPassword,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            labelText: title,
            labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white, width: 2.0),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
            suffixIcon: isPassword
                ? Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          showPassword = !showPassword;
                        });
                      },
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _errorMessage() {
    return errorMessage == null || errorMessage!.isEmpty
        ? const SizedBox.shrink()
        : SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red[300], fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _submitButton() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          height: 56,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : signInWithEmailAndPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color.fromARGB(225, 0, 74, 173),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color.fromARGB(225, 0, 74, 173),
                      ),
                    ),
                  )
                : const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _loginOrRegisterButton() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: TextButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ConsultantRegisterPage(),
            ),
          );
        },
        child: Text(
          "Don't have an account? \n Sign Up",
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFamily: 'Quicksand',
          ),
        ),
      ),
    );
  }

  Widget _forgotPassword() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PasswordPage()),
          );
        },
        child: Text(
          'Forgot Password?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Quicksand',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _animationController.dispose();
    _controllerEmail.dispose();
    _controllerPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
                  if (isLargeScreen)
                    Expanded(
                      flex: 1,
                      child: Container(
                        color: const Color.fromARGB(225, 0, 74, 173),
                        child: Center(
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _appBarImage(),
                                  const SizedBox(height: 32),
                                  _title(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: isLargeScreen ? 2 : 1,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 100 : 24,
                          vertical: 40,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: _welcomeText(),
                            ),
                            const SizedBox(height: 48),
                            SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Consultant Login',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _entryField('Email', _controllerEmail),
                                      const SizedBox(height: 16),
                                      _entryField(
                                        'Password',
                                        _controllerPassword,
                                        isPassword: true,
                                      ),
                                      _errorMessage(),
                                      const SizedBox(height: 16),
                                      _submitButton(),
                                      _forgotPassword(),
                                      _loginOrRegisterButton(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
