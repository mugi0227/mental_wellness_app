import 'package:flutter/foundation.dart';
import 'package:mental_wellness_app/models/medication_model.dart'; // For Medication type
import 'local_notification_service_stub.dart'
    if (dart.library.io) 'local_notification_service_mobile.dart'
    if (dart.library.html) 'local_notification_service_web.dart';

class LocalNotificationService {
  dynamic _flutterLocalNotificationsPlugin;

  Future<void> initialize() async {
    if (!kIsWeb) {
      _flutterLocalNotificationsPlugin = createNotificationPlugin();
    }
    if (!kIsWeb) {
      initializeTimeZones(); // Initialize timezone data
    }

    if (kIsWeb) {
      // Web notifications will be handled differently
      return;
    }

    // Android initialization settings
    final initializationSettingsAndroid = createAndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    final initializationSettingsIOS = createDarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    final initializationSettings = createInitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await initializeNotificationPlugin(
      _flutterLocalNotificationsPlugin,
      initializationSettings,
      _onDidReceiveNotificationResponse,
      _onDidReceiveBackgroundNotificationResponse,
    );

    // Create Android Notification Channel (for Android 8.0+)
    _createAndroidNotificationChannel();
    
    // Request permissions on iOS if not already granted via initialization settings
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _requestIOSPermissions();
    }
  }

  Future<void> _requestIOSPermissions() async {
    if (kIsWeb) return;
    await requestIOSPermissions(_flutterLocalNotificationsPlugin);
  }

  void _createAndroidNotificationChannel() async {
    if (kIsWeb) return;
    await createAndroidNotificationChannel(_flutterLocalNotificationsPlugin);
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
  void _onDidReceiveNotificationResponse(dynamic notificationResponse) async {
    if (kIsWeb) return;
    final String? payload = getNotificationPayload(notificationResponse);
    if (kDebugMode) {
      print('Notification response received: payload=$payload');
    }
    // Handle navigation or other actions based on payload
    // e.g., if (payload == 'medication_reminder_123') { ... }
  }

  // Callback for when a background notification response is received
  static void _onDidReceiveBackgroundNotificationResponse(dynamic notificationResponse) {
     if (kIsWeb) return;
     final String? payload = getNotificationPayload(notificationResponse);
     if (kDebugMode) {
      print('Background notification response received: payload=$payload');
    }
    // Handle navigation or other actions based on payload
  }

  // --- End of existing callbacks ---

  dynamic _nextInstanceOfTime(int hour, int minute) {
    if (kIsWeb) return null;
    return getNextInstanceOfTime(hour, minute);
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final isGranted = await checkAndRequestScheduleExactAlarmPermission();
      if (!isGranted) {
        print('Error: SCHEDULE_EXACT_ALARM permission not granted. Medication reminder for ${medication.name} cannot be scheduled exactly.');
        return;
      }
    }

    for (int i = 0; i < medication.times.length; i++) {
      final timeStr = medication.times[i];
      try {
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final notificationId = _generateNotificationId(medication.id!, i);

        if (kIsWeb) {
          // Web notifications would be handled differently
          if (kDebugMode) {
            print('Web notifications not yet implemented for ${medication.name} at $timeStr');
          }
        } else {
          await scheduleNotification(
            _flutterLocalNotificationsPlugin,
            notificationId,
            'お薬の時間です💊',
            '「${medication.name}」(${medication.dosage}) を服用しましょう。',
            _nextInstanceOfTime(hour, minute),
            'medication_reminder|${medication.id}|$timeStr',
          );
        }
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
     if (!kIsWeb && _flutterLocalNotificationsPlugin != null) {
       await cancelNotification(_flutterLocalNotificationsPlugin, notificationId);
     }
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
      if (!kIsWeb && _flutterLocalNotificationsPlugin != null) {
        await cancelNotification(_flutterLocalNotificationsPlugin, notificationId);
      }
      if (kDebugMode) {
        print('Cancelled reminder for medicationId $medicationId, timeIndex $i (ID: $notificationId)');
      }
    }
  }
}
