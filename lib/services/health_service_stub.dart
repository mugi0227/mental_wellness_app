// スタブファイル：条件付きインポートのインターフェース定義

dynamic getHealthInstance() => throw UnsupportedError(
    'Cannot create health instance without dart:io or dart:html');

bool isIOS() => throw UnsupportedError(
    'Platform check not supported');

dynamic getSleepAsleepType() => throw UnsupportedError(
    'Health data types not available');

dynamic getSleepSessionType() => throw UnsupportedError(
    'Health data types not available');

dynamic getReadPermission() => throw UnsupportedError(
    'Health permissions not available');

Future<bool?> hasHealthPermissions(dynamic health, List<dynamic> types) =>
    throw UnsupportedError('Health permissions not available');

Future<bool> requestHealthAuthorization(
    dynamic health, List<dynamic> types, List<dynamic> permissions) =>
    throw UnsupportedError('Health authorization not available');

Future<List<dynamic>> getHealthDataFromTypes(
    dynamic health, DateTime startTime, DateTime endTime, List<dynamic> types) =>
    throw UnsupportedError('Health data not available');

double? getNumericHealthValue(dynamic point) =>
    throw UnsupportedError('Health data not available');

List<dynamic> getHealthDataTypes() =>
    throw UnsupportedError('Health data types not available');

Future<bool> requestHealthAuthorizationForTypes(
    dynamic health, List<dynamic> types) =>
    throw UnsupportedError('Health authorization not available');

dynamic getStepsType() =>
    throw UnsupportedError('Health data types not available');

dynamic getActiveEnergyType() =>
    throw UnsupportedError('Health data types not available');