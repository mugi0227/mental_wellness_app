import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:mental_wellness_app/models/medication_model.dart'; // For Medication type
import 'package:permission_handler/permission_handler.dart'; // For handling permissions

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones(); // Initialize timezone data

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Ensure this drawable exists

    // iOS initialization settings
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    // Linux initialization settings (optional, for desktop)
    // final LinuxInitializationSettings initializationSettingsLinux = 
    //    LinuxInitializationSettings(defaultActionName: 'Open notification');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      // linux: initializationSettingsLinux,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
    );

    // Create Android Notification Channel (for Android 8.0+)
    _createAndroidNotificationChannel();
    
    // Request permissions on iOS if not already granted via initialization settings
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _requestIOSPermissions();
    }
  }

  Future<void> _requestIOSPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _createAndroidNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'medication_reminders', // id
      'Medication Reminders', // title
      description: 'Channel for medication reminder notifications.', // description
      importance: Importance.high,
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Callback for when a notification is received while the app is in the foreground (iOS older versions)
  void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // Display a dialog or handle the notification
    if (kDebugMode) {
      print('Foreground iOS notification received: id=$id, title=$title, body=$body, payload=$payload');
    }
    // You might want to show a dialog here or navigate
  }

  // Callback for when a notification response is received (e.g., user taps on notification)
  void _onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (kDebugMode) {
      print('Notification response received: payload=$payload');
    }
    // Handle navigation or other actions based on payload
    // e.g., if (payload == 'medication_reminder_123') { ... }
  }

  // Callback for when a background notification response is received
  static void _onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
     if (kDebugMode) {
      print('Background notification response received: payload=\${notificationResponse.payload}');
    }
    // Handle navigation or other actions based on payload
  }

  // --- End of existing callbacks ---

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Generates a unique notification ID for a medication time.
  // medicationId.hashCode can be negative, ensure positive and within int32 range.
  int _generateNotificationId(String medicationId, int timeIndex) {
    // Simple scheme: (medicationId's hash) + timeIndex.
    // Ensure positive and reasonably spread.
    // Max 32-bit int is 2^31 - 1. We'll use a smaller modulo to avoid collisions with other potential notification types if any.
    final baseId = medicationId.hashCode.abs() % 1000000; // Keep it well within limits
    return baseId * 100 + timeIndex; // Allows up to 100 times per medication, which is plenty.
  }

  Future<void> scheduleMedicationReminder(Medication medication) async {
    if (!medication.reminderEnabled || medication.id == null) return;

    // Androidで正確なアラームの権限を確認・リクエスト
    if (defaultTargetPlatform == TargetPlatform.android) {
      var status = await Permission.scheduleExactAlarm.status;
      if (kDebugMode) {
        print('SCHEDULE_EXACT_ALARM permission status: $status');
      }
      if (status.isDenied) { // isDenied は、まだリクエストしていないか、一度拒否された場合
        status = await Permission.scheduleExactAlarm.request();
        if (kDebugMode) {
          print('SCHEDULE_EXACT_ALARM permission status after request: $status');
        }
      }
      
      // isPermanentlyDenied の場合や、リクエスト後も許可されなかった場合
      if (!status.isGranted) { 
        if (kDebugMode) {
          print('SCHEDULE_EXACT_ALARM permission was not granted. Cannot schedule exact alarms.');
          // 必要であれば、ユーザーに設定画面を開くよう促すメッセージをUI層で表示することを検討
          // await openAppSettings(); // これを呼び出すとアプリ設定画面が開く
        }
        // UI層でユーザーに通知するか、フォールバックの通知方法を検討
        // ここではエラーログを残し、スケジュールしない
        print('Error: SCHEDULE_EXACT_ALARM permission not granted. Medication reminder for ${medication.name} cannot be scheduled exactly.');
        return; // スケジュール処理を中断
      }
    }

    for (int i = 0; i < medication.times.length; i++) {
      final timeStr = medication.times[i];
      try {
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final notificationId = _generateNotificationId(medication.id!, i);

        await _flutterLocalNotificationsPlugin.zonedSchedule(
          notificationId,
          'お薬の時間です💊',
          '「${medication.name}」(${medication.dosage}) を服用しましょう。',
          _nextInstanceOfTime(hour, minute),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'medication_reminders', // Channel ID (must match created channel)
              'Medication Reminders', // Channel Name
              channelDescription: 'Channel for medication reminder notifications.',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher', // Ensure this icon exists
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at this time
          payload: 'medication_reminder|${medication.id}|$timeStr',
        );
        if (kDebugMode) {
          print('Scheduled reminder for ${medication.name} at $timeStr (ID: $notificationId)');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error scheduling reminder for ${medication.name} at $timeStr: $e');
        }
      }
    }
  }

  Future<void> cancelSpecificReminder(String medicationId, int timeIndex) async {
     final notificationId = _generateNotificationId(medicationId, timeIndex);
     await _flutterLocalNotificationsPlugin.cancel(notificationId);
     if (kDebugMode) {
        print('Cancelled specific reminder for medicationId $medicationId, timeIndex $timeIndex (ID: $notificationId)');
     }
  }

  Future<void> cancelAllRemindersForMedication(String medicationId, int numberOfTimes) async {
    if (kDebugMode) {
      print('Attempting to cancel all reminders for medicationId: $medicationId for $numberOfTimes times');
    }
    for (int i = 0; i < numberOfTimes; i++) {
      // It's crucial that numberOfTimes reflects how many were actually scheduled.
      // If we don't know, we might have to cancel a wider range of IDs or query pending notifications.
      final notificationId = _generateNotificationId(medicationId, i);
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
      if (kDebugMode) {
        print('Cancelled reminder for medicationId $medicationId, timeIndex $i (ID: $notificationId)');
      }
    }
  }
}
