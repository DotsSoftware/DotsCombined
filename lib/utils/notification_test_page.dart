import 'notification_helper.dart';
import 'onesignal_service.dart';
import 'notification_service.dart';
import 'notification_config.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Testing',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use these buttons to test and verify push notifications are working properly.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // OneSignal Tests
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OneSignal Tests',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _checkOneSignalStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('Check OneSignal Status'),
                    ),
                    const SizedBox(height: 8),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _requestOneSignalPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('Request OneSignal Permissions'),
                    ),
                    const SizedBox(height: 8),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testOneSignalNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('Test OneSignal Notification'),
                    ),
                    const SizedBox(height: 8),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testOneSignalIndustryNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('Test OneSignal Industry Notification'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Existing Notification Tests
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Existing Notification Tests',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _checkNotificationStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('Check Notification Status'),
                    ),
                    const SizedBox(height: 8),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _requestPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('Request Permissions'),
                    ),
                    const SizedBox(height: 8),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _getFcmToken,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('Get FCM Token'),
                    ),
                    const SizedBox(height: 8),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _showTestNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('Show Test Notification'),
                    ),
                    const SizedBox(height: 8),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testNotificationSystem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('Test Complete Notification System'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Status Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        _statusText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Configuration Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuration Status',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NotificationConfig.isOneSignalConfigured 
                            ? Colors.green[50] 
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: NotificationConfig.isOneSignalConfigured 
                              ? Colors.green[300]! 
                              : Colors.orange[300]!,
                        ),
                      ),
                      child: Text(
                        NotificationConfig.validationMessage,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NotificationConfig.isOneSignalConfigured 
                              ? Colors.green[700] 
                              : Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Make sure you have granted notification permissions\n'
                      '• Test both OneSignal and existing notification systems\n'
                      '• Check that notifications appear whether app is open or closed\n'
                      '• Verify that notification actions (Accept/Reject) work properly\n'
                      '• Test industry-specific notifications for consultants\n'
                      '• Update OneSignal App ID in notification_config.dart if needed',
                      style: Theme.of(context).textTheme.bodyMedium,
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

  // OneSignal Test Methods
  Future<void> _checkOneSignalStatus() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Checking OneSignal status...';
    });

    try {
      bool isSubscribed = await OneSignalService.isSubscribed();
      String? playerId = await OneSignalService.getCurrentPlayerId();
      
      setState(() {
        _statusText = 'OneSignal Status:\n'
            '• Subscribed: $isSubscribed\n'
            '• Player ID: ${playerId ?? 'Not available'}';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error checking OneSignal status: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestOneSignalPermissions() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Requesting OneSignal permissions...';
    });

    try {
      bool granted = await OneSignalService.requestPermissions();
      setState(() {
        _statusText = 'OneSignal permissions granted: $granted';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error requesting OneSignal permissions: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testOneSignalNotification() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Sending OneSignal test notification...';
    });

    try {
      await OneSignalService.testOneSignalSystem();
      setState(() {
        _statusText = 'OneSignal test notification sent! Check your notification panel.';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error sending OneSignal test notification: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testOneSignalIndustryNotification() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Sending OneSignal industry test notification...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // This will test industry notification if the current user is a consultant
        await OneSignalService.testOneSignalSystem();
        setState(() {
          _statusText = 'OneSignal industry test notification sent!';
        });
      } else {
        setState(() {
          _statusText = 'No user logged in. Please log in as a consultant to test industry notifications.';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = 'Error sending OneSignal industry test notification: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Existing Notification Test Methods
  Future<void> _checkNotificationStatus() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Checking notification status...';
    });

    try {
      await NotificationHelper.checkNotificationStatus();
      await AppNotificationService.checkNotificationSystemStatus();
      setState(() {
        _statusText = 'Notification status check completed. Check console for details.';
      });
    } catch (e) {
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
      _statusText = 'Requesting permissions...';
    });

    try {
      bool granted = await NotificationHelper.requestPermissions();
      setState(() {
        _statusText = 'Permissions granted: $granted';
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
        _statusText = 'FCM token: ${token ?? 'Not available'}';
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

  Future<void> _testNotificationSystem() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Testing complete notification system...';
    });

    try {
      await AppNotificationService.testNotificationSystem();
      setState(() {
        _statusText = 'Complete notification system test completed! Check console for details.';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error testing notification system: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
