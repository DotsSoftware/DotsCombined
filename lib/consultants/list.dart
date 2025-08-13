import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'request_details.dart';
import '../utils/theme.dart';
import '../utils/notification_service.dart';
import '../consultants/consultant_notification_listener.dart';

class NotificationsListPage extends StatefulWidget {
  const NotificationsListPage({Key? key}) : super(key: key);

  @override
  State<NotificationsListPage> createState() => _NotificationsListPageState();
}

class _NotificationsListPageState extends State<NotificationsListPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _consultantIndustryType;
  String? _currentUserId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Track the last notification timestamp
  DateTime? _lastNotificationTime;

  // Stream subscription for notifications
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _getConsultantData();
    WidgetsBinding.instance.addObserver(this);

    // Initialize notification listener
    _initNotificationListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _notificationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - restart listener if needed
      _initNotificationListener();
    } else if (state == AppLifecycleState.paused) {
      // App going to background - clean up
      _notificationSubscription?.cancel();
    }
  }

  void _initNotificationListener() {
    if (_consultantIndustryType == null || _currentUserId == null) return;

    _notificationSubscription?.cancel();

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('industry_type', isEqualTo: _consultantIndustryType)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          _handleNewNotifications(snapshot);
        });
  }

  void _handleNewNotifications(QuerySnapshot snapshot) {
    final now = DateTime.now();

    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;

        if (timestamp != null) {
          final notificationTime = timestamp.toDate();

          // Only show notification if it's new (within last 5 minutes)
          if (_lastNotificationTime == null ||
              notificationTime.isAfter(
                _lastNotificationTime!.subtract(const Duration(minutes: 5)),
              )) {
            _showNewRequestNotification(requestId: change.doc.id, data: data);

            _lastNotificationTime = notificationTime;
          }
        }
      }
    }
  }

  Future<void> _showNewRequestNotification({
    required String requestId,
    required Map<String, dynamic> data,
  }) async {
    // Only show if the request is still searching
    if (data['status'] != 'searching') return;

    final payload = AppNotificationService.convertPayload({
      'type': 'client_request',
      'requestId': requestId,
      'industry': _consultantIndustryType,
      'timestamp': data['timestamp']?.toDate().toString() ?? '',
      'clientId': data['clientId'] ?? '',
      'consultantId': _currentUserId,
      'jobDate': data['jobDate'] ?? '',
      'jobTime': data['jobTime'] ?? '',
      'siteLocation': data['siteLocation'] ?? '',
      'jobDescription': data['jobDescription'] ?? '',
    });

    await AppNotificationService.showNotification(
      title: '📌 New Client Request',
      body:
          'New request in $_consultantIndustryType - ${data['siteLocation'] ?? 'Location not specified'}',
      payload: payload,
      channelKey: 'client_requests_channel',
      actionButtons: [
        NotificationActionButton(
          key: 'ACCEPT',
          label: 'Accept',
          actionType: ActionType.Default,
          color: Colors.green,
        ),
        NotificationActionButton(
          key: 'REJECT',
          label: 'Reject',
          actionType: ActionType.Default,
          color: Colors.red,
        ),
      ],
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

  Future<void> _getConsultantData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUserId = user.uid;

        DocumentSnapshot consultantDoc = await FirebaseFirestore.instance
            .collection('consultant_register')
            .doc(user.uid)
            .get();

        if (consultantDoc.exists) {
          final data = consultantDoc.data() as Map<String, dynamic>;
          setState(() {
            _consultantIndustryType = data['industry_type'] as String?;
          });
          _initNotificationListener(); // Initialize listener after getting industry type
        }
      }
    } catch (e) {
      print('Error getting consultant data: $e');
    }
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;

    final searchLower = _searchQuery.toLowerCase();

    return (data['industry_type']?.toString().toLowerCase() ?? '').contains(
          searchLower,
        ) ||
        (data['siteLocation']?.toString().toLowerCase() ?? '').contains(
          searchLower,
        ) ||
        (data['jobDate']?.toString().toLowerCase() ?? '').contains(
          searchLower,
        ) ||
        (data['jobTime']?.toString().toLowerCase() ?? '').contains(searchLower);
  }

  Widget _buildModernCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String? status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case 'searching':
        color = Colors.orange;
        icon = Icons.search;
        text = 'Searching';
        break;
      case 'accepted':
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Accepted';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        text = 'Rejected';
        break;
      case 'completed':
        color = Colors.blue;
        icon = Icons.done_all;
        text = 'Completed';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (_consultantIndustryType != null)
                                Text(
                                  'Industry: $_consultantIndustryType',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search notifications...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF1E3A8A),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Notifications List
              Expanded(
                child: _consultantIndustryType == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notifications')
                            .where(
                              'industry_type',
                              isEqualTo: _consultantIndustryType,
                            )
                            .orderBy('timestamp', descending: true)
                            .limit(50)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
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
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Error: ${snapshot.error}',
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
                            );
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1E3A8A),
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.notifications_none,
                                        size: 64,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No notifications available',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final filteredDocs = snapshot.data!.docs
                              .where(
                                (doc) => _matchesSearch(
                                  doc.data() as Map<String, dynamic>,
                                ),
                              )
                              .toList();

                          if (filteredDocs.isEmpty) {
                            return Center(
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 64,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No matching notifications found',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              var notification = filteredDocs[index];
                              var data =
                                  notification.data() as Map<String, dynamic>;
                              String displayDate =
                                  '${data['jobDate'] ?? 'No date'} at ${data['jobTime'] ?? 'No time'}';

                              return SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: _buildModernCard(
                                    title:
                                        data['industry_type'] ??
                                        'Unknown Industry',
                                    icon: Icons.notifications,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayDate,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          data['siteLocation'] ??
                                              'No location specified',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildStatusIndicator(
                                              data['status'],
                                            ),
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          RequestDetailsPage(
                                                            documentId:
                                                                notification.id,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 16,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'View Details',
                                                    style: TextStyle(
                                                      color: Color(0xFF1E3A8A),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
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
                              );
                            },
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
