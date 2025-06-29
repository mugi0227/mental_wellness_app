// モバイル実装：iOS/Android向けの通知機能

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

dynamic createNotificationPlugin() => FlutterLocalNotificationsPlugin();

void initializeTimeZones() => tz.initializeTimeZones();

dynamic createAndroidInitializationSettings(String icon) =>
    AndroidInitializationSettings(icon);

dynamic createDarwinInitializationSettings({
  required bool requestAlertPermission,
  required bool requestBadgePermission,
  required bool requestSoundPermission,
  required void Function(int, String?, String?, String?) onDidReceiveLocalNotification,
}) =>
    DarwinInitializationSettings(
      requestAlertPermission: requestAlertPermission,
      requestBadgePermission: requestBadgePermission,
      requestSoundPermission: requestSoundPermission,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

dynamic createInitializationSettings({
  required dynamic android,
  required dynamic iOS,
}) =>
    InitializationSettings(
      android: android as AndroidInitializationSettings?,
      iOS: iOS as DarwinInitializationSettings?,
    );

Future<void> initializeNotificationPlugin(
  dynamic plugin,
  dynamic settings,
  void Function(dynamic) onDidReceiveNotificationResponse,
  void Function(dynamic) onDidReceiveBackgroundNotificationResponse,
) async {
  await (plugin as FlutterLocalNotificationsPlugin).initialize(
    settings as InitializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) =>
        onDidReceiveNotificationResponse(response),
    onDidReceiveBackgroundNotificationResponse: (NotificationResponse response) =>
        onDidReceiveBackgroundNotificationResponse(response),
  );
}

Future<void> requestIOSPermissions(dynamic plugin) async {
  await (plugin as FlutterLocalNotificationsPlugin)
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
}

Future<void> createAndroidNotificationChannel(dynamic plugin) async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'medication_reminders',
    'Medication Reminders',
    description: 'Channel for medication reminder notifications.',
    importance: Importance.high,
    playSound: true,
  );

  await (plugin as FlutterLocalNotificationsPlugin)
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

String? getNotificationPayload(dynamic notificationResponse) {
  return (notificationResponse as NotificationResponse).payload;
}

dynamic getNextInstanceOfTime(int hour, int minute) {
  final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  tz.TZDateTime scheduledDate =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }
  return scheduledDate;
}

Future<bool> checkAndRequestScheduleExactAlarmPermission() async {
  var status = await Permission.scheduleExactAlarm.status;
  if (kDebugMode) {
    print('SCHEDULE_EXACT_ALARM permission status: $status');
  }
  if (status.isDenied) {
    status = await Permission.scheduleExactAlarm.request();
    if (kDebugMode) {
      print('SCHEDULE_EXACT_ALARM permission status after request: $status');
    }
  }
  
  if (!status.isGranted) {
    if (kDebugMode) {
      print('SCHEDULE_EXACT_ALARM permission was not granted. Cannot schedule exact alarms.');
    }
    return false;
  }
  return true;
}

Future<void> scheduleNotification(
  dynamic plugin,
  int id,
  String title,
  String body,
  dynamic scheduledDate,
  String payload,
) async {
  await (plugin as FlutterLocalNotificationsPlugin).zonedSchedule(
    id,
    title,
    body,
    scheduledDate as tz.TZDateTime,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_reminders',
        'Medication Reminders',
        channelDescription: 'Channel for medication reminder notifications.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
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
    matchDateTimeComponents: DateTimeComponents.time,
    payload: payload,
  );
}

Future<void> cancelNotification(dynamic plugin, int id) async {
  await (plugin as FlutterLocalNotificationsPlugin).cancel(id);
}