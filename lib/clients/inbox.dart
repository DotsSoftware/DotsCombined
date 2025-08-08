import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient
import 'direct_chat.dart';
import 'login_register_page.dart';
import 'continue.dart'; // Assuming ContinuePage is the navigation target

class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({Key? key}) : super(key: key);

  @override
  _ChatInboxPageState createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage>
    with TickerProviderStateMixin {
  String? currentUserId;
  bool _isLoading = true;
  String? errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeUser();
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          errorMessage = 'Please sign in to view messages';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to view messages'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        setState(() {
          currentUserId = user.uid;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error initializing user: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing user: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';

    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('dd MMM yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('register')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final firstName = userData['firstName']?.toString() ?? '';
        final surname = userData['surname']?.toString() ?? '';
        final fullName = '$firstName $surname'.trim();
        _userNameCache[userId] = fullName.isEmpty ? 'Unknown User' : fullName;
        return _userNameCache[userId]!;
      }
      _userNameCache[userId] = 'Unknown User';
      return 'Unknown User';
    } catch (e) {
      _userNameCache[userId] = 'Unknown User';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching user name: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return 'Unknown User';
    }
  }

  Future<String> _getAppointmentSubtitle(DocumentSnapshot chatDoc) async {
    try {
      final data = chatDoc.data() as Map<String, dynamic>?;
      if (data == null ||
          !data.containsKey('appointmentId') ||
          data['appointmentId'] == null) {
        return 'Direct Message';
      }

      final appointmentId = data['appointmentId'] as String;
      if (appointmentId.isEmpty) {
        return 'Direct Message';
      }

      final appointment = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(appointmentId)
          .get();

      if (appointment.exists) {
        final appointmentData = appointment.data() as Map<String, dynamic>?;
        if (appointmentData != null &&
            appointmentData.containsKey('jobDescription')) {
          return 'Job: ${appointmentData['jobDescription'] ?? 'No description'}';
        }
      }
      return 'Direct Message';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching appointment details: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return 'Direct Message';
    }
  }

  void _navigateToChat(String chatId) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DirectPage(chatId: chatId)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error navigating to chat: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildChatCard({required DocumentSnapshot chat, required int index}) {
    final data = chat.data() as Map<String, dynamic>? ?? {};
    final participants = data['participants'] as List<dynamic>? ?? [];
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String>(
      future: _getUserName(otherUserId),
      builder: (context, userSnapshot) {
        return FutureBuilder<String>(
          future: _getAppointmentSubtitle(chat),
          builder: (context, appointmentSnapshot) {
            final subtitle = appointmentSnapshot.data ?? 'Loading...';
            final userName = userSnapshot.data ?? 'Loading...';
            final timestamp = _formatTimestamp(
              data['lastMessageTime'] is Timestamp ? data['lastMessageTime'] as Timestamp : null,
            );

            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: Offset(0, 0.1 * index),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                    ),
                  ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTap: () => _navigateToChat(chat.id),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF1E3A8A),
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          timestamp,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || currentUserId == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: appGradient),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading Messages...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header - Changed title to "Inbox"
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
                            'Inbox', // Changed from 'Messages'
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
              ),

              // Error Message
              if (errorMessage != null)
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
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

              // Chat List - Modified query to avoid indexing issues
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('inbox')
                      .where('participants', arrayContains: currentUserId)
                      .orderBy('lastMessageTime', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading Messages...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading messages: ${snapshot.error}',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setState(() {}),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 24,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E3A8A),
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
                                  'Retry',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) =>
                          _buildChatCard(chat: snapshot.data!.docs[index], index: index),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
