import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'aipage.dart';
import 'appointment_database.dart';
import 'chat.dart';
import 'consultant_login.dart';
import 'customer_care.dart';
import 'feedback.dart';
import 'industry_selection.dart';
import 'invoice_database.dart';
import 'personal_information.dart';
import 'profile.dart';
import 'settings.dart';
import 'notification.dart';
import 'request_database.dart';
import 'request_type.dart';
import 'inbox.dart';
import 'wallet.dart';

class ConsultantDashboardPage extends StatefulWidget {
  const ConsultantDashboardPage({Key? key}) : super(key: key);

  @override
  _ConsultantDashboardPageState createState() =>
      _ConsultantDashboardPageState();
}

class _ConsultantDashboardPageState extends State<ConsultantDashboardPage>
    with TickerProviderStateMixin {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isVerified = false;
  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideUpAnimation;
  late Animation<double> _cardStaggerAnimation;

  final List<Map<String, dynamic>> menuItems = [
    {
      'icon': Icons.notification_important_outlined,
      'title': 'Requests',
      'page': RequestDatabase(),
    },
    {
      'icon': Icons.calendar_today_outlined,
      'title': 'Appointments',
      'page': AppointmentDatabase(),
    },
    {'icon': Icons.work_outline, 'title': 'Jobs', 'page': RequestDatabase()},
  ];

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
    _createBannerAd();
    _initAnimations();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideUpAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
          ),
        );

    _cardStaggerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _cardAnimationController.forward();
    });
  }

  Future<void> _checkVerificationStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('consultant_register')
          .doc(user.uid)
          .get();

      setState(() {
        _isVerified = userDoc['applicationStatus'] == 'verified';
      });
    }
  }

  void _createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5630199363228429/1139015448',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
          print('Ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: ${error.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> getUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('consultant_register')
          .doc(user.uid)
          .get();
      return {
        'firstName': userDoc['firstName'] ?? '',
        'surname': userDoc['surname'] ?? '',
        'isDisabled': userDoc['isDisabled'] ?? false,
        'email': userDoc['email'] ?? '',
        'applicationStatus': userDoc['applicationStatus'] ?? '',
      };
    }
    return {
      'firstName': '',
      'surname': '',
      'isDisabled': false,
      'email': '',
      'applicationStatus': '',
    };
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required int index,
    required bool isEnabled,
  }) {
    return AnimatedBuilder(
      animation: _cardStaggerAnimation,
      builder: (context, child) {
        final staggeredValue = Curves.elasticOut.transform(
          (_cardStaggerAnimation.value - (index * 0.1)).clamp(0.0, 1.0),
        );

        return Transform.translate(
          offset: Offset(0, 30 * (1 - staggeredValue)),
          child: Opacity(
            opacity: staggeredValue,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isEnabled ? onTap : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? const Color(0xFF4A90E2)
                                : Colors.grey,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(icon, color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isEnabled
                                ? const Color(0xFF2C5282)
                                : Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, Map<String, dynamic> userData) {
    final bool isDisabled = userData['isDisabled'] ?? false;
    final String email = userData['email'] ?? '';
    final bool isBlacklisted = isDisabled || email.endsWith('.blacklisted');

    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A90E2), Color(0xFF2C5282)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Text(
                      userData['firstName']?.isNotEmpty ?? false
                          ? userData['firstName'][0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF2C5282),
                      ),
                    ),
                  ),
                ),
                title: const Text(
                  'Welcome!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${userData['firstName'] ?? ''} ${userData['surname'] ?? ''}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildDrawerItem(
                icon: Icons.person_3_outlined,
                title: 'Profile',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  );
                },
                isDisabled: isBlacklisted,
              ),
              _buildDrawerItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Personal Information',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PersonalInformation(),
                    ),
                  );
                },
                isDisabled: isBlacklisted || _isVerified,
              ),
              _buildDrawerItem(
                icon: Icons.wallet_outlined,
                title: 'Wallet',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WalletPage()),
                  );
                },
                isDisabled: isBlacklisted,
              ),
              _buildDrawerItem(
                icon: Icons.calendar_today,
                title: 'Appointments',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppointmentDatabase(),
                    ),
                  );
                },
                isDisabled: isBlacklisted,
              ),
              _buildDrawerItem(
                icon: Icons.support_agent,
                title: 'Support',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(initialMessage: ''),
                    ),
                  );
                },
                isDisabled: isBlacklisted,
              ),
              _buildDrawerItem(
                icon: Icons.feedback_rounded,
                title: 'Feedback',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FeedbackPage()),
                  );
                },
                isDisabled: isBlacklisted,
              ),
              _buildDrawerItem(
                icon: Icons.settings,
                title: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsPage()),
                  );
                },
                isDisabled: isBlacklisted,
              ),
              _buildDrawerItem(
                icon: Icons.exit_to_app,
                title: 'Logout',
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConsultantLoginPage(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
                isDisabled: false,
              ),
              const Spacer(),
              const Divider(color: Colors.white30),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    required bool isDisabled,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: isDisabled ? null : onTap,
      enabled: !isDisabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      hoverColor: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildBlacklistBanner() {
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red[700]!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red[700],
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Disabled',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please contact our office for assistance',
                    style: TextStyle(color: Colors.red[700], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> getImageUrlFromFirebase() async {
    return 'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/dash2.png?alt=media&token=312ccf58-5f27-4bb8-ad00-ac131b0a6865';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7FA),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
              ),
            ),
          );
        }

        final bool isDisabled = snapshot.data?['isDisabled'] ?? false;
        final String email = snapshot.data?['email'] ?? '';
        final bool isBlacklisted = isDisabled || email.endsWith('.blacklisted');

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text(
              'Consultant Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFF1E3A8A),
            elevation: 0,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Container(
                    width: 24,
                    height: 24,
                    child: Image.network(
                      'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  onPressed: () {
                    // Handle dots icon press
                  },
                ),
              ),
            ],
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ),
          endDrawer: _buildDrawer(context, snapshot.data ?? {}),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBlacklisted) _buildBlacklistBanner(),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF4A90E2).withOpacity(0.3),
                          ),
                        ),
                        child: FutureBuilder<String>(
                          future: getImageUrlFromFirebase(),
                          builder: (context, imageSnapshot) {
                            if (imageSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF4A90E2),
                                  ),
                                ),
                              );
                            }
                            if (imageSnapshot.hasError ||
                                !imageSnapshot.hasData) {
                              return const Center(
                                child: Text('Error loading image'),
                              );
                            }
                            return Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A90E2),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.handshake_outlined,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'How can we help you?',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2C5282),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Manage your consulting services',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF718096),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SlideTransition(
                      position: _slideUpAnimation,
                      child: FadeTransition(
                        opacity: _fadeInAnimation,
                        child: const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C5282),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SlideTransition(
                      position: _slideUpAnimation,
                      child: FadeTransition(
                        opacity: _fadeInAnimation,
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                          children: menuItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            bool isEnabled = !isBlacklisted;
                            if (item['title'] == 'Requests') {
                              isEnabled = !isBlacklisted && _isVerified;
                            }
                            return _buildQuickActionCard(
                              icon: item['icon'],
                              title: item['title'],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => item['page'],
                                ),
                              ),
                              index: index,
                              isEnabled: isEnabled,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isAdLoaded && _bannerAd != null)
                      Container(
                        alignment: Alignment.center,
                        width: _bannerAd!.size.width.toDouble(),
                        height: _bannerAd!.size.height.toDouble(),
                        child: AdWidget(ad: _bannerAd!),
                      ),
                    if (!_isAdLoaded)
                      Container(
                        padding: const EdgeInsets.all(8),
                        height: 50,
                        alignment: Alignment.center,
                        child: const Text(
                          "Advertisement loading...",
                          style: TextStyle(color: Color(0xFF718096)),
                        ),
                      ),
                  ],
                ),
              ),
              if (isBlacklisted)
                Positioned.fill(
                  child: AbsorbPointer(
                    absorbing: true,
                    child: Container(color: Colors.black.withOpacity(0.1)),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: isBlacklisted
                  ? Colors.grey
                  : const Color(0xFF4A90E2),
              unselectedItemColor: isBlacklisted
                  ? Colors.grey
                  : const Color(0xFF718096),
              currentIndex: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_rounded),
                  label: 'Appointments',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inbox_rounded),
                  label: 'Inbox',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
              onTap: isBlacklisted
                  ? null
                  : (index) {
                      switch (index) {
                        case 0:
                          break;
                        case 1:
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AppointmentDatabase(),
                            ),
                          );
                          break;
                        case 2:
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InboxPage(),
                            ),
                          );
                          break;
                        case 3:
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfilePage(),
                            ),
                          );
                          break;
                      }
                    },
            ),
          ),
        );
      },
    );
  }
}
