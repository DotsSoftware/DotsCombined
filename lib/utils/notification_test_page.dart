import 'notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../clients/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationTestPage extends StatefulWidget {
  @override
  _NotificationTestPageState createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  String _statusText = 'Ready to test notifications';
  bool _isLoading = false;
  String? _currentToken;
  List<String> _testResults = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkNotificationStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Test & Debug'),
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(),
            SizedBox(height: 16),
            
            // Test Buttons Grid
            _buildTestButtonsGrid(),
            SizedBox(height: 16),
            
            // Advanced Tests
            _buildAdvancedTestsCard(),
            SizedBox(height: 16),
            
            // Debug Information
            _buildDebugInfoCard(),
            SizedBox(height: 16),
            
            // Test Results
            _buildTestResultsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text(
                  'Notification Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (_currentToken != null) ...[
              SizedBox(height: 12),
              Text(
                'Current FCM Token:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _currentToken!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Token copied to clipboard')),
                    );
                  },
                  child: Text(
                    '${_currentToken!.substring(0, 50)}...\n(Tap to copy)',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestButtonsGrid() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.play_arrow, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text(
                  'Basic Tests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildTestButton(
                  'Check Status',
                  Icons.check_circle_outline,
                  _isLoading ? null : _checkNotificationStatus,
                ),
                _buildTestButton(
                  'Get FCM Token',
                  Icons.token,
                  _isLoading ? null : _getFcmToken,
                ),
                _buildTestButton(
                  'Request Permissions',
                  Icons.security,
                  _isLoading ? null : _requestPermissions,
                ),
                _buildTestButton(
                  'Show Test Notification',
                  Icons.notifications_active,
                  _isLoading ? null : _showTestNotification,
                ),
                _buildTestButton(
                  'Clear Cache',
                  Icons.clear_all,
                  _isLoading ? null : _clearCache,
                ),
                _buildTestButton(
                  'Refresh Token',
                  Icons.refresh,
                  _isLoading ? null : _refreshToken,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedTestsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text(
                  'Advanced Tests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildTestButton(
              'Test FCM Endpoint',
              Icons.send,
              _isLoading ? null : _testFcmEndpoint,
              fullWidth: true,
            ),
            SizedBox(height: 12),
            _buildTestButton(
              'Simulate Search Notification',
              Icons.search,
              _isLoading ? null : _simulateSearchNotification,
              fullWidth: true,
            ),
            SizedBox(height: 12),
            _buildTestButton(
              'Check Firestore Tokens',
              Icons.storage,
              _isLoading ? null : _checkFirestoreTokens,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text(
                  'Debug Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Troubleshooting Tips:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            ),
            SizedBox(height: 8),
            Text(
              '• Make sure you have granted notification permissions\n'
              '• Check if your device has internet connectivity\n'
              '• Ensure Firebase project is correctly configured\n'
              '• Verify that FCM tokens are being stored in Firestore\n'
              '• Check app logs for any error messages\n'
              '• Try clearing cache and refreshing tokens\n'
              '• Ensure the app is in foreground for test notifications',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultsCard() {
    if (_testResults.isEmpty) return SizedBox.shrink();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text(
                  'Test Results',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () => setState(() => _testResults.clear()),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              height: 200,
              width: double.infinity,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _testResults.join('\n'),
                  style: TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
    String title,
    IconData icon,
    VoidCallback? onPressed, {
    bool fullWidth = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: fullWidth ? 16 : 12,
          horizontal: fullWidth ? 24 : 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: fullWidth ? 16 : 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _addTestResult(String result) {
    setState(() {
      _testResults.add('[${DateTime.now().toString().substring(11, 19)}] $result');
    });
  }

  Future<void> _checkNotificationStatus() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Checking notification status...';
    });

    try {
      await NotificationHelper.checkNotificationStatus();
      _addTestResult('✓ Notification status check completed');
      setState(() {
        _statusText = 'Notification status check completed. Check console logs for details.';
      });
    } catch (e) {
      _addTestResult('✗ Status check failed: $e');
      setState(() {
        _statusText = 'Error checking notification status: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Requesting notification permissions...';
    });

    try {
      bool granted = await NotificationHelper.requestPermissions();
      _addTestResult('${granted ? "✓" : "✗"} Permission request: ${granted ? "Granted" : "Denied"}');
      setState(() {
        _statusText = granted 
            ? 'Notification permissions granted!'
            : 'Notification permissions denied. Please enable in device settings.';
      });
    } catch (e) {
      _addTestResult('✗ Permission request failed: $e');
      setState(() {
        _statusText = 'Error requesting permissions: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getFcmToken() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Getting FCM token...';
    });

    try {
      String? token = await NotificationHelper.getAndStoreFcmToken(forceRefresh: true);
      if (token != null) {
        _addTestResult('✓ FCM token retrieved successfully');
        setState(() {
          _currentToken = token;
          _statusText = 'FCM token retrieved and stored successfully!';
        });
      } else {
        _addTestResult('✗ Failed to retrieve FCM token');
        setState(() {
          _statusText = 'Failed to get FCM token. Check permissions and network connection.';
        });
      }
    } catch (e) {
      _addTestResult('✗ FCM token error: $e');
      setState(() {
        _statusText = 'Error getting FCM token: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showTestNotification() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Showing test notification...';
    });

    try {
      await NotificationHelper.showTestNotification();
      _addTestResult('✓ Test notification sent');
      setState(() {
        _statusText = 'Test notification sent! Check your notification panel.';
      });
    } catch (e) {
      _addTestResult('✗ Test notification failed: $e');
      setState(() {
        _statusText = 'Error showing test notification: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Clearing notification cache...';
    });

    try {
      await NotificationHelper.clearTokenCache();
      _addTestResult('✓ Cache cleared successfully');
      setState(() {
        _statusText = 'Notification cache cleared!';
        _currentToken = null;
      });
    } catch (e) {
      _addTestResult('✗ Cache clear failed: $e');
      setState(() {
        _statusText = 'Error clearing cache: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshToken() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Refreshing FCM token...';
    });

    try {
      await NotificationHelper.clearTokenCache();
      String? token = await NotificationHelper.getAndStoreFcmToken(forceRefresh: true);
      if (token != null) {
        _addTestResult('✓ Token refreshed successfully');
        setState(() {
          _currentToken = token;
          _statusText = 'FCM token refreshed successfully!';
        });
      } else {
        _addTestResult('✗ Token refresh failed');
        setState(() {
          _statusText = 'Failed to refresh FCM token.';
        });
      }
    } catch (e) {
      _addTestResult('✗ Token refresh error: $e');
      setState(() {
        _statusText = 'Error refreshing token: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testFcmEndpoint() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Testing FCM endpoint...';
    });

    try {
      String? token = await NotificationHelper.getAndStoreFcmToken();
      if (token == null) {
        throw Exception('No FCM token available');
      }

      final FirebaseAuthService authService = FirebaseAuthService();
      final String accessToken = await authService.getAccessToken();

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/dots-b3559/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': '🧪 FCM Endpoint Test',
              'body': 'FCM endpoint is working correctly!',
            },
            'data': {
              'test': 'true',
              'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        _addTestResult('✓ FCM endpoint test successful (${response.statusCode})');
        setState(() {
          _statusText = 'FCM endpoint test successful! Check for notification.';
        });
      } else {
        _addTestResult('✗ FCM endpoint test failed (${response.statusCode}): ${response.body}');
        setState(() {
          _statusText = 'FCM endpoint test failed: ${response.statusCode}';
        });
      }
    } catch (e) {
      _addTestResult('✗ FCM endpoint test error: $e');
      setState(() {
        _statusText = 'FCM endpoint test error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _simulateSearchNotification() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Simulating search notification...';
    });

    try {
      String? token = await NotificationHelper.getAndStoreFcmToken();
      if (token == null) {
        throw Exception('No FCM token available');
      }

      final FirebaseAuthService authService = FirebaseAuthService();
      final String accessToken = await authService.getAccessToken();

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/dots-b3559/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': '📌 New Request Available',
              'body': 'New client request in Technology',
            },
            'data': {
              'type': 'client_request',
              'requestId': 'test_request_${DateTime.now().millisecondsSinceEpoch}',
              'industry': 'Technology',
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
          },
        }),
      );

      if (response.statusCode == 200) {
        _addTestResult('✓ Search notification simulation successful');
        setState(() {
          _statusText = 'Search notification simulated successfully!';
        });
      } else {
        _addTestResult('✗ Search notification simulation failed (${response.statusCode})');
        setState(() {
          _statusText = 'Search notification simulation failed: ${response.statusCode}';
        });
      }
    } catch (e) {
      _addTestResult('✗ Search notification simulation error: $e');
      setState(() {
        _statusText = 'Search notification simulation error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkFirestoreTokens() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Checking Firestore tokens...';
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      String? currentToken = await NotificationHelper.getAndStoreFcmToken();
      
      DocumentSnapshot clientDoc = await FirebaseFirestore.instance
          .collection('register')
          .doc(user.uid)
          .get();

      DocumentSnapshot consultantDoc = await FirebaseFirestore.instance
          .collection('consultant_register')
          .doc(user.uid)
          .get();

      Map<String, dynamic>? clientData = clientDoc.data() as Map<String, dynamic>?;
      Map<String, dynamic>? consultantData = consultantDoc.data() as Map<String, dynamic>?;

      String clientStatus = clientDoc.exists && clientData?['fcmToken'] == currentToken 
          ? '✓ Valid' : '✗ Invalid/Missing';
      String consultantStatus = consultantDoc.exists && consultantData?['fcmToken'] == currentToken 
          ? '✓ Valid' : '✗ Invalid/Missing';

      _addTestResult('Firestore Token Check:');
      _addTestResult('- Client Register: $clientStatus');
      _addTestResult('- Consultant Register: $consultantStatus');

      setState(() {
        _statusText = 'Firestore token check completed. See results below.';
      });
    } catch (e) {
      _addTestResult('✗ Firestore token check error: $e');
      setState(() {
        _statusText = 'Firestore token check error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
