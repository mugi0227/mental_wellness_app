// モバイル実装：iOS/Android向けのhealth関連機能

import 'dart:io';
import 'package:health/health.dart';

dynamic getHealthInstance() => Health();

bool isIOS() => Platform.isIOS;

dynamic getSleepAsleepType() => HealthDataType.SLEEP_ASLEEP;

dynamic getSleepSessionType() => HealthDataType.SLEEP_SESSION;

dynamic getReadPermission() => HealthDataAccess.READ;

Future<bool?> hasHealthPermissions(dynamic health, List<dynamic> types) async {
  return await (health as Health).hasPermissions(types.cast<HealthDataType>());
}

Future<bool> requestHealthAuthorization(
    dynamic health, List<dynamic> types, List<dynamic> permissions) async {
  return await (health as Health).requestAuthorization(
    types.cast<HealthDataType>(),
    permissions: permissions.cast<HealthDataAccess>(),
  );
}

Future<List<dynamic>> getHealthDataFromTypes(
    dynamic health, DateTime startTime, DateTime endTime, List<dynamic> types) async {
  return await (health as Health).getHealthDataFromTypes(
    startTime: startTime,
    endTime: endTime,
    types: types.cast<HealthDataType>(),
  );
}

double? getNumericHealthValue(dynamic point) {
  if ((point as HealthDataPoint).value is NumericHealthValue) {
    return (point.value as NumericHealthValue).numericValue.toDouble();
  }
  return null;
}

List<dynamic> getHealthDataTypes() {
  return [
    HealthDataType.SLEEP_ASLEEP,      // 睡眠時間 (睡眠中)
    HealthDataType.SLEEP_AWAKE,       // 睡眠時間 (覚醒)
    HealthDataType.SLEEP_IN_BED,      // ベッドにいた時間
    HealthDataType.STEPS,             // 歩数
    HealthDataType.ACTIVE_ENERGY_BURNED, // アクティブカロリー
  ];
}

Future<bool> requestHealthAuthorizationForTypes(
    dynamic health, List<dynamic> types) async {
  return await (health as Health).requestAuthorization(
    types.cast<HealthDataType>(),
  );
}

dynamic getStepsType() => HealthDataType.STEPS;

dynamic getActiveEnergyType() => HealthDataType.ACTIVE_ENERGY_BURNED;