# OneSignal Setup Guide

This guide will help you set up OneSignal notifications in your Flutter app to work alongside the existing notification system.

## Prerequisites

1. OneSignal account (free tier available)
2. Firebase project already configured
3. Flutter app with existing notification system

## Step 1: Create OneSignal App

1. Go to [OneSignal Dashboard](https://app.onesignal.com/)
2. Click "New App/Website"
3. Choose "Mobile App" and select "Flutter"
4. Enter your app name (e.g., "Dots Business App")
5. Click "Create App"

## Step 2: Configure OneSignal App Settings

### Android Configuration

1. In your OneSignal app dashboard, go to "Settings" > "Message Display"
2. Configure notification settings:
   - **Default Notification Icon**: Upload your app icon (24x24dp)
   - **Accent Color**: Set to your app's primary color (#1E3A8A)
   - **Notification Sound**: Choose default or custom sound
   - **Vibration**: Enable for better user experience

3. Go to "Settings" > "Mobile Push"
4. Configure Android settings:
   - **FCM Server Key**: Add your Firebase FCM server key
   - **Default Channel ID**: Set to "high_importance_channel"
   - **Default Channel Name**: Set to "High Importance Notifications"

### iOS Configuration (if applicable)

1. Go to "Settings" > "Mobile Push"
2. Configure iOS settings:
   - **APNs Auth Key**: Upload your APNs auth key
   - **APNs Key ID**: Enter your key ID
   - **APNs Team ID**: Enter your team ID
   - **Bundle ID**: Enter your app's bundle identifier

## Step 3: Update App Configuration

### 1. Update OneSignal App ID

In `lib/utils/onesignal_service.dart`, replace the placeholder with your actual OneSignal App ID:

```dart
static const String _oneSignalAppId = 'YOUR_ACTUAL_ONESIGNAL_APP_ID';
```

### 2. Android Manifest Configuration

Add the following to your `android/app/src/main/AndroidManifest.xml` inside the `<application>` tag:

```xml
<meta-data
    android:name="onesignal_app_id"
    android:value="YOUR_ONESIGNAL_APP_ID" />
<meta-data
    android:name="onesignal_google_project_number"
    android:value="YOUR_FIREBASE_PROJECT_NUMBER" />
```

### 3. iOS Configuration (if applicable)

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>OneSignal_app_groups_key</key>
<string>group.com.yourcompany.yourapp</string>
```

## Step 4: Test OneSignal Integration

1. Build and run your app
2. Navigate to the Notification Test Page
3. Test OneSignal functionality:
   - Check OneSignal Status
   - Request OneSignal Permissions
   - Test OneSignal Notification
   - Test OneSignal Industry Notification

## Step 5: Verify Integration

### Check Console Logs

Look for these success messages in your console:

```
✅ OneSignal initialized successfully
✅ OneSignal user ID set: [user_id]
✅ OneSignal Player ID stored for user: [user_id]
```

### Test Notifications

1. **Foreground Test**: Send a test notification while the app is open
2. **Background Test**: Send a test notification while the app is in background
3. **Closed App Test**: Send a test notification while the app is completely closed

## Step 6: Configure Notification Templates (Optional)

In your OneSignal dashboard, you can create notification templates for common scenarios:

### Client Request Template

1. Go to "Templates" > "New Template"
2. Name: "Client Request Notification"
3. Content:
   - Title: "📌 New Client Request"
   - Message: "New request in {{industry}} - {{location}}"
4. Add variables: `{{industry}}`, `{{location}}`, `{{requestId}}`

### Industry-Specific Templates

Create separate templates for different industries with customized messaging.

## Step 7: Advanced Configuration

### Custom Notification Channels

You can create additional notification channels for different types of notifications:

```dart
// In OneSignalService.initialize()
await OneSignal.Notifications.addChannel(
  OSNotificationChannel(
    id: 'client_requests_channel',
    name: 'Client Requests',
    description: 'Notifications for new client requests',
    importance: OSNotificationImportance.High,
  ),
);
```

### Rich Notifications

Configure rich notifications with images and action buttons:

```dart
await OneSignalService.sendNotificationToUsers(
  playerIds: playerIds,
  title: 'New Request',
  body: 'You have a new client request',
  data: {'requestId': '123', 'type': 'client_request'},
  imageUrl: 'https://example.com/notification-image.jpg',
);
```

## Troubleshooting

### Common Issues

1. **Notifications not appearing**:
   - Check OneSignal App ID is correct
   - Verify FCM server key is properly configured
   - Ensure notification permissions are granted

2. **Player ID not generated**:
   - Check internet connection
   - Verify OneSignal initialization is successful
   - Check console logs for errors

3. **Notifications not working in background**:
   - Verify background message handler is properly configured
   - Check OneSignal dashboard for delivery status
   - Ensure app is not being killed by the system

### Debug Mode

Enable debug mode in OneSignal service:

```dart
OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
```

### Check Delivery Status

In your OneSignal dashboard, go to "Analytics" to see:
- Delivery rates
- Open rates
- Click rates
- Error rates

## Integration with Existing System

The OneSignal implementation works alongside your existing notification system:

1. **Dual Sending**: Both systems send notifications simultaneously
2. **Fallback**: If one system fails, the other ensures delivery
3. **Consistent UI**: Both use the same notification handler page
4. **Unified Testing**: Test page includes both systems

## Best Practices

1. **User Segmentation**: Use OneSignal's segmentation features to target specific user groups
2. **A/B Testing**: Test different notification messages and timing
3. **Analytics**: Monitor notification performance and user engagement
4. **Rate Limiting**: Implement rate limiting to avoid spam
5. **Personalization**: Use user data to personalize notification content

## Security Considerations

1. **API Keys**: Keep your OneSignal App ID and FCM server key secure
2. **User Privacy**: Respect user notification preferences
3. **Data Protection**: Ensure notification payload doesn't contain sensitive information
4. **Compliance**: Follow GDPR and other privacy regulations

## Support

If you encounter issues:

1. Check OneSignal documentation: https://documentation.onesignal.com/
2. Review Flutter OneSignal plugin: https://pub.dev/packages/onesignal_flutter
3. Check console logs for detailed error messages
4. Use the notification test page to isolate issues

## Next Steps

After successful setup:

1. Monitor notification delivery rates
2. Optimize notification timing and content
3. Implement advanced features like scheduled notifications
4. Set up notification analytics and reporting
5. Consider implementing notification preferences in your app settings