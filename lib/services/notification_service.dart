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

    // ユーザーが通知を許可した場合のみ、リスナー設定とトークン取得に進む
    if (settings.authorizationStatus == AuthorizationStatus.authorized || 
        settings.authorizationStatus == AuthorizationStatus.provisional) {
          
      _setupFCMListeners();
      await _getAndSaveFCMToken();

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
        if (navigatorKey.currentState?.mounted == true && navigatorKey.currentState?.context != null && message.notification != null) {
           _showNotificationDialog(message, navigatorKey.currentState!.context);
        }
      }
    });

    // Handle messages when app is opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          print('App opened from terminated state by notification: ${message.messageId}');
        }
        if (navigatorKey.currentState?.mounted == true && navigatorKey.currentState?.context != null && message.notification != null) {
          _showNotificationDialog(message, navigatorKey.currentState!.context);
        }
      }
    });
    
    // Handle messages when app is opened from a background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('App opened from background by notification: ${message.messageId}');
      }
      if (navigatorKey.currentState?.mounted == true && navigatorKey.currentState?.context != null && message.notification != null) {
        _showNotificationDialog(message, navigatorKey.currentState!.context);
      }
    });

    // Set the background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // ★★★ ここからが修正の核心部分です ★★★
  Future<void> _getAndSaveFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print("User not logged in, cannot save FCM token.");
      }
      return;
    }

    final userProfile = await _firestoreService.getUserProfile(user.uid);
    if (userProfile == null) {
      if (kDebugMode) {
        print("User profile for ${user.uid} does not exist yet. FCM token cannot be saved until profile is created.");
      }
      return;
    }

    try {
      String? token;
      // Webかどうかでトークンの取得方法を分岐させる
      if (kIsWeb) {
        // Firebaseコンソールで取得したVAPIDキーを指定
        const String? vapidKey = "BFZ1LmrXX0DEFFauaws3Gaq7KkF3B6mkDk_VZ3cynVDkthz4AX4ODbyfdg9I5vA7gOrunA2Q5K5B_62vfIA_gLI"; 
        token = await _firebaseMessaging.getToken(vapidKey: vapidKey);
      } else {
        // モバイルの場合はVAPIDキーは不要
        token = await _firebaseMessaging.getToken();
      }

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

    // Listen for token refresh (この部分は元のままでOK)
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        print('FCM Token Refreshed: $newToken');
      }
      _firestoreService.saveUserFCMToken(user.uid, newToken);
    });
  }

  // 以下、他のメソッドは変更なし
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    if (kDebugMode) {
      print('Subscribed to topic: $topic');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    if (kDebugMode) {
      print('Unsubscribed from topic: $topic');
    }
  }
}