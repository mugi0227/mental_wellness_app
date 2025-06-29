import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mental_wellness_app/main.dart'; // For navigatorKey
import 'package:mental_wellness_app/services/firestore_service.dart'; // To save FCM token
import 'package:firebase_auth/firebase_auth.dart';

// It's good practice to define the onBackgroundMessage handler as a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, like Firestore,
  // make sure you call `initializeApp` before using them.
  // await Firebase.initializeApp(); // Already initialized in main.dart usually

  debugPrint("Handling a background message: ${message.messageId}");
  debugPrint('Message data: ${message.data}');
  debugPrint('Message notification: ${message.notification?.title} / ${message.notification?.body}');
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> initialize() async {
    // Request permission
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
      print('User granted permission: ${settings.authorizationStatus}');
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      _setupFCMListeners();
      _getAndSaveFCMToken();
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      if (kDebugMode) {
        print('User granted provisional permission');
      }
      _setupFCMListeners();
      _getAndSaveFCMToken();
    } else {
      if (kDebugMode) {
        print('User declined or has not accepted permission');
      }
    }
  }

  void _showNotificationDialog(RemoteMessage message, BuildContext context) {
    if (message.notification != null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(message.notification!.title ?? "通知"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message.notification!.body ?? "新しいメッセージがあります。"),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  void _setupFCMListeners() {
    // Handle messages while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
      }

      if (message.notification != null) {
        if (kDebugMode) {
          print('Message also contained a notification: ${message.notification?.title} / ${message.notification?.body}');
        }
        // Display an in-app dialog for foreground messages
        if (navigatorKey.currentState?.mounted == true && navigatorKey.currentState?.context != null && message.notification != null) {
           _showNotificationDialog(message, navigatorKey.currentState!.context);
        }
      }
    });

    // Handle messages when app is opened from a terminated state by tapping on a notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          print('App opened from terminated state by notification: ${message.messageId}');
        }
        // Handle navigation or specific action based on message.data
        if (navigatorKey.currentState?.mounted == true && navigatorKey.currentState?.context != null && message.notification != null) {
          _showNotificationDialog(message, navigatorKey.currentState!.context);
        }
      }
    });
    
    // Handle messages when app is opened from a background state by tapping on a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('App opened from background by notification: ${message.messageId}');
      }
      // Handle navigation or specific action based on message.data
      if (navigatorKey.currentState?.mounted == true && navigatorKey.currentState?.context != null && message.notification != null) {
        _showNotificationDialog(message, navigatorKey.currentState!.context);
      }
    });

    // Set the background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _getAndSaveFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print("User not logged in, cannot save FCM token.");
      }
      return;
    }

    // Check if user profile exists before attempting to save FCM token
    final userProfile = await _firestoreService.getUserProfile(user.uid);
    if (userProfile == null) {
      if (kDebugMode) {
        print("User profile for ${user.uid} does not exist yet. FCM token cannot be saved until profile is created.");
      }
      return;
    }

    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        if (kDebugMode) {
          print('FCM Token: $token');
        }
        await _firestoreService.saveUserFCMToken(user.uid, token);
      } else {
        if (kDebugMode) {
          print("Failed to get FCM token.");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error getting or saving FCM token: $e");
      }
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        print('FCM Token Refreshed: $newToken');
      }
      // user is guaranteed to be non-null here because the parent function _getAndSaveFCMToken would have returned early if user was null.
      _firestoreService.saveUserFCMToken(user.uid, newToken);
    });
  }

  // Example method to subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    if (kDebugMode) {
      print('Subscribed to topic: $topic');
    }
  }

  // Example method to unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    if (kDebugMode) {
      print('Unsubscribed from topic: $topic');
    }
  }
}
