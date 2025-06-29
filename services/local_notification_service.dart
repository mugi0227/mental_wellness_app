import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones(); // Initialize timezone data

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Ensure ic_launcher exists

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        // Handle notification tapped while app is in foreground for iOS <= 9
      },
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tapped
        if (response.payload != null) {
          // print('Notification payload: \${response.payload}');
          // You can add navigation logic here if needed
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
     // Create Android Notification Channel (moved from AndroidManifest for newer plugin versions)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'medication_reminders_channel', // id
      'Medication Reminders', // name
      description: 'Channel for medication reminder notifications.', // description
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('default'), // Ensure you have a default sound or use other sound type
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> showMedicationReminderNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'medication_reminders_channel', // Channel ID
      'Medication Reminders', // Channel Name
      channelDescription: 'Channel for medication reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('default'),
      icon: '@mipmap/ic_launcher', // Ensure this icon exists
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default', // Ensure this sound is available or use a custom one
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}

// Top-level function for background notification taps
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // print('notification(${notificationResponse.id}) action tapped: '
  //       '\${notificationResponse.actionId} with'
  //       ' payload: \${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    // print('notification action tapped with input: \${notificationResponse.input}');
  }
  // Handle work here
}
