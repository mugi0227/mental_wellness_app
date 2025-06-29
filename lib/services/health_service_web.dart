// Web実装：Web向けのhealth関連機能（基本的に無効化）

dynamic getHealthInstance() => null;

bool isIOS() => false;

dynamic getSleepAsleepType() => null;

dynamic getSleepSessionType() => null;

dynamic getReadPermission() => null;

Future<bool?> hasHealthPermissions(dynamic health, List<dynamic> types) async {
  return false;
}

Future<bool> requestHealthAuthorization(
    dynamic health, List<dynamic> types, List<dynamic> permissions) async {
  return false;
}

Future<List<dynamic>> getHealthDataFromTypes(
    dynamic health, DateTime startTime, DateTime endTime, List<dynamic> types) async {
  return [];
}

double? getNumericHealthValue(dynamic point) {
  return null;
}

List<dynamic> getHealthDataTypes() {
  return [];
}

Future<bool> requestHealthAuthorizationForTypes(
    dynamic health, List<dynamic> types) async {
  return false;
}

dynamic getStepsType() => null;

dynamic getActiveEnergyType() => null;