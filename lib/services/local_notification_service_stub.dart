// スタブファイル：条件付きインポートのインターフェース定義

dynamic createNotificationPlugin() => throw UnsupportedError(
    'Cannot create notification plugin without dart:io or dart:html');

void initializeTimeZones() => throw UnsupportedError(
    'Cannot initialize timezones without dart:io or dart:html');

dynamic createAndroidInitializationSettings(String icon) => throw UnsupportedError(
    'Cannot create Android settings without dart:io');

dynamic createDarwinInitializationSettings({
  required bool requestAlertPermission,
  required bool requestBadgePermission,
  required bool requestSoundPermission,
  required void Function(int, String?, String?, String?) onDidReceiveLocalNotification,
}) => throw UnsupportedError(
    'Cannot create iOS settings without dart:io');

dynamic createInitializationSettings({
  required dynamic android,
  required dynamic iOS,
}) => throw UnsupportedError(
    'Cannot create initialization settings without dart:io');

Future<void> initializeNotificationPlugin(
  dynamic plugin,
  dynamic settings,
  void Function(dynamic) onDidReceiveNotificationResponse,
  void Function(dynamic) onDidReceiveBackgroundNotificationResponse,
) => throw UnsupportedError(
    'Cannot initialize notification plugin without dart:io');

Future<void> requestIOSPermissions(dynamic plugin) => throw UnsupportedError(
    'Cannot request iOS permissions without dart:io');

Future<void> createAndroidNotificationChannel(dynamic plugin) => throw UnsupportedError(
    'Cannot create Android notification channel without dart:io');

String? getNotificationPayload(dynamic notificationResponse) => throw UnsupportedError(
    'Cannot get notification payload without dart:io');

dynamic getNextInstanceOfTime(int hour, int minute) => throw UnsupportedError(
    'Cannot get next instance of time without dart:io');

Future<bool> checkAndRequestScheduleExactAlarmPermission() => throw UnsupportedError(
    'Cannot check permissions without dart:io');

Future<void> scheduleNotification(
  dynamic plugin,
  int id,
  String title,
  String body,
  dynamic scheduledDate,
  String payload,
) => throw UnsupportedError(
    'Cannot schedule notification without dart:io');

Future<void> cancelNotification(dynamic plugin, int id) => throw UnsupportedError(
    'Cannot cancel notification without dart:io');