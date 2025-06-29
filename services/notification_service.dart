import 'package:firebase_messaging/firebase_messaging.dart';
import './local_notification_service.dart'; // Import LocalNotificationService
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuth
import '../lib/services/firestore_service.dart'; // For FirestoreService

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  // await Firebase.initializeApp(); // Not usually needed here if main.dart already initializes

  // print("Handling a background message: \${message.messageId}");
  // print('Message data: \${message.data}');
  // print('Message notification: \${message.notification?.title} / \${message.notification?.body}');

  if (message.data['type'] == 'medication_reminder') {
    final localNotificationService = LocalNotificationService();
    // Ensure LocalNotificationService is initialized for background isolate if it wasn't already.
    // This might require careful handling if initialization is complex or depends on Flutter bindings.
    // For simpler cases, direct call might work or you might need to pass initialized instance or use a singleton.
    // await localNotificationService.initialize(); // Call initialize if it's safe and idempotent
    
    localNotificationService.showMedicationReminderNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title: message.data['title'] ?? message.notification?.title ?? 'お薬の時間です',
      body: message.data['body'] ?? message.notification?.body ?? 'お薬を服用しましょう。',
      payload: message.data['medicationId'], // Optional: pass medicationId as payload
    );
  }
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final LocalNotificationService _localNotificationService = LocalNotificationService();

  Future<void> initialize() async {
    await _requestPermissions();
    await _getToken();
    _configureForegroundMessageHandler();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // Handle notification tap when app is terminated
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        // print("App launched by terminated notification tap: \${message.data}");
        _handleMessageNavigation(message.data);
      }
    });

    // Handle notification tap when app is in background (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // print("App opened from background by notification tap: \${message.data}");
      _handleMessageNavigation(message.data);
    });
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      // print('User granted permission: \${settings.authorizationStatus}');
    }
  }

  Future<void> _getToken() async {
    String? token = await _firebaseMessaging.getToken();
    if (kDebugMode) {
      // print("Firebase Messaging Token: \$token");
    }
    // Here you would typically send the token to your backend server
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      await FirestoreService().saveUserFCMToken(user.uid, token);
    } else if (kDebugMode) {
      // print("User not logged in or token is null, cannot save FCM token.");
    }
  }

  void _configureForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // print('Got a message whilst in the foreground!');
      // print('Message data: \${message.data}');

      if (message.notification != null) {
        // print('Message also contained a notification: \${message.notification}');
      }

      // Check if it's a medication reminder
      if (message.data['type'] == 'medication_reminder') {
        _localNotificationService.showMedicationReminderNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID for the notification
          title: message.data['title'] ?? message.notification?.title ?? 'お薬の時間です',
          body: message.data['body'] ?? message.notification?.body ?? 'お薬を服用しましょう。',
          payload: message.data['medicationId'], // Optional: pass medicationId as payload
        );
      }
      // Handle other types of foreground messages if necessary
    });
  }

  void _handleMessageNavigation(Map<String, dynamic> data) {
    // Example: Navigate if a specific key exists in data
    // This needs to be adapted based on your app's navigation and data structure
    // final String? type = data['type'];
    // final String? itemId = data['itemId']; // e.g. medicationId, insightId

    // if (type == 'medication_reminder' && itemId != null) {
      // Navigate to medication detail screen or relevant part of the app
      // e.g. navigatorKey.currentState?.pushNamed('/medication-detail', arguments: itemId);
    // }
  }
}
