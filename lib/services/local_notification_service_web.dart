// Web実装：Web向けの通知機能（基本的に無効化）

dynamic createNotificationPlugin() => null;

void initializeTimeZones() {
  // Web では timezone パッケージは使用しない
}

dynamic createAndroidInitializationSettings(String icon) => null;

dynamic createDarwinInitializationSettings({
  required bool requestAlertPermission,
  required bool requestBadgePermission,
  required bool requestSoundPermission,
  required void Function(int, String?, String?, String?) onDidReceiveLocalNotification,
}) => null;

dynamic createInitializationSettings({
  required dynamic android,
  required dynamic iOS,
}) => null;

Future<void> initializeNotificationPlugin(
  dynamic plugin,
  dynamic settings,
  void Function(dynamic) onDidReceiveNotificationResponse,
  void Function(dynamic) onDidReceiveBackgroundNotificationResponse,
) async {
  // Web では実装しない
}

Future<void> requestIOSPermissions(dynamic plugin) async {
  // Web では実装しない
}

Future<void> createAndroidNotificationChannel(dynamic plugin) async {
  // Web では実装しない
}

String? getNotificationPayload(dynamic notificationResponse) {
  return null;
}

dynamic getNextInstanceOfTime(int hour, int minute) {
  return null;
}

Future<bool> checkAndRequestScheduleExactAlarmPermission() async {
  return false;
}

Future<void> scheduleNotification(
  dynamic plugin,
  int id,
  String title,
  String body,
  dynamic scheduledDate,
  String payload,
) async {
  // Web では Notification API を使用することも可能だが、
  // 現時点では実装しない
}

Future<void> cancelNotification(dynamic plugin, int id) async {
  // Web では実装しない
}