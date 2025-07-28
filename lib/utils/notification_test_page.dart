import 'package:flutter/material.dart';
import 'notification_helper.dart';

class NotificationTestPage extends StatefulWidget {
  @override
  _NotificationTestPageState createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  String _statusText = 'Ready to test notifications';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Test'),
        backgroundColor: Color.fromARGB(225, 0, 74, 173),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Push Notification Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use these buttons to test and verify push notifications are working properly.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _checkNotificationStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(225, 0, 74, 173),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Check Notification Status'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _requestPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Request Permissions'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _getFcmToken,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Get FCM Token'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _showTestNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Show Test Notification'),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (_isLoading)
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading...'),
                        ],
                      )
                    else
                      Text(
                        _statusText,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
            ),
            Spacer(),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Troubleshooting Tips:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Make sure you have granted notification permissions\n'
                      '• Check that you are logged in to the app\n'
                      '• Verify your device has internet connection\n'
                      '• Check the console logs for detailed error messages',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkNotificationStatus() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Checking notification status...';
    });

    try {
      await NotificationHelper.checkNotificationStatus();
      setState(() {
        _statusText = 'Status check completed. Check console for details.';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error checking status: $e';
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
      _statusText = 'Requesting permissions...';
    });

    try {
      bool granted = await NotificationHelper.requestPermissions();
      setState(() {
        _statusText = granted
            ? 'Permissions granted successfully!'
            : 'Permissions denied. Please enable in device settings.';
      });
    } catch (e) {
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
      String? token = await NotificationHelper.getAndStoreFcmToken();
      setState(() {
        _statusText = token != null
            ? 'FCM token obtained and stored successfully!'
            : 'Failed to get FCM token. Check console for details.';
      });
    } catch (e) {
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
      setState(() {
        _statusText = 'Test notification sent! Check your notification panel.';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error showing test notification: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
