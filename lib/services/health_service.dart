import 'package:health/health.dart';
import 'package:flutter/foundation.dart'; // Required for debugPrint
import 'dart:io';

class HealthService {
  static final Health _health = Health();
  static bool _isAuthorized = false;

  // Define the data types you want to access
  static const List<HealthDataType> _dataTypes = [
    HealthDataType.SLEEP_ASLEEP,      // 睡眠時間 (睡眠中)
    HealthDataType.SLEEP_AWAKE,       // 睡眠時間 (覚醒)
    HealthDataType.SLEEP_IN_BED,      // ベッドにいた時間
    HealthDataType.STEPS,             // 歩数
    HealthDataType.ACTIVE_ENERGY_BURNED, // アクティブカロリー
    // Add other types as needed, e.g., HEART_RATE, BODY_TEMPERATURE
  ];

  static Future<bool> checkHealthPermissions() async {
    try {
      final types = Platform.isIOS 
          ? [HealthDataType.SLEEP_ASLEEP]
          : [HealthDataType.SLEEP_SESSION];
      
      return await _health.hasPermissions(types) ?? false;
    } catch (e) {
      debugPrint('Error checking health permissions: $e');
      return false;
    }
  }

  static Future<bool> requestHealthPermissions() async {
    try {
      final types = Platform.isIOS 
          ? [HealthDataType.SLEEP_ASLEEP]
          : [HealthDataType.SLEEP_SESSION];
      
      final permissions = [HealthDataAccess.READ];
      
      return await _health.requestAuthorization(types, permissions: permissions);
    } catch (e) {
      debugPrint('Error requesting health permissions: $e');
      return false;
    }
  }

  /// Requests authorization to access health data.
  /// Returns true if authorization is granted, false otherwise.
  Future<bool> requestAuthorization() async {
    if (_isAuthorized) return true;

    // Request authorization for all defined types
    // The HealthFactory constructor has an optional types parameter, 
    // but requestAuthorization is preferred for clarity and dynamic requests.
    // For Health Connect, specific permissions need to be declared in AndroidManifest.xml
    // For HealthKit, usage descriptions (NSHealthShareUsageDescription, NSHealthUpdateUsageDescription)
    // need to be added to Info.plist.
    try {
      _isAuthorized = await _health.requestAuthorization(_dataTypes);
      return _isAuthorized;
    } catch (e) {
      debugPrint("Error requesting health authorization: $e");
      return false;
    }
  }

  static Future<double?> getSleepData(DateTime startDate, DateTime endDate) async {
    try {
      final types = Platform.isIOS
          ? [HealthDataType.SLEEP_ASLEEP]
          : [HealthDataType.SLEEP_SESSION];
      
      final healthData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: types,
      );
      
      if (healthData.isEmpty) return null;
      
      double totalMinutes = 0;
      for (final point in healthData) {
        if (point.value is NumericHealthValue) {
          totalMinutes += (point.value as NumericHealthValue).numericValue.toDouble();
        }
      }
      
      return totalMinutes / 60; // Convert to hours
    } catch (e) {
      debugPrint('Error fetching sleep data: $e');
      return null;
    }
  }

  /// Fetches sleep data for the given date range.
  Future<List<HealthDataPoint>> getSleepDataPoints(DateTime startDate, DateTime endDate) async {
    if (!_isAuthorized) {
      debugPrint("Health data not authorized. Please request authorization first.");
      bool authorized = await requestAuthorization();
      if (!authorized) return [];
    }

    List<HealthDataPoint> sleepData = [];
    try {
      // Fetch sleep data (asleep duration)
      List<HealthDataPoint> asleep = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: [HealthDataType.SLEEP_ASLEEP],
      );
      sleepData.addAll(asleep);
      // You might want to process different sleep types (SLEEP_AWAKE, SLEEP_IN_BED)
      // to get a more comprehensive view of sleep.
    } catch (e) {
      debugPrint("Error fetching sleep data: $e");
    }
    return sleepData;
  }

  /// Fetches step count for the given date range.
  Future<int> getTotalSteps(DateTime startDate, DateTime endDate) async {
    if (!_isAuthorized) {
      debugPrint("Health data not authorized. Please request authorization first.");
      bool authorized = await requestAuthorization();
      if (!authorized) return 0;
    }

    int totalSteps = 0;
    try {
      List<HealthDataPoint> stepsData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: [HealthDataType.STEPS],
      );
      for (var dataPoint in stepsData) {
        if (dataPoint.value is NumericHealthValue) {
          totalSteps += (dataPoint.value as NumericHealthValue).numericValue.toInt();
        }
      }
    } catch (e) {
      debugPrint("Error fetching steps data: $e");
    }
    return totalSteps;
  }

  /// Fetches active energy burned for the given date range.
  Future<double> getTotalActiveEnergy(DateTime startDate, DateTime endDate) async {
    if (!_isAuthorized) {
      debugPrint("Health data not authorized. Please request authorization first.");
      bool authorized = await requestAuthorization();
      if (!authorized) return 0.0;
    }

    double totalEnergy = 0.0;
    try {
      List<HealthDataPoint> energyData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      for (var dataPoint in energyData) {
         if (dataPoint.value is NumericHealthValue) {
          totalEnergy += (dataPoint.value as NumericHealthValue).numericValue.toDouble();
        }
      }
    } catch (e) {
      debugPrint("Error fetching active energy data: $e");
    }
    return totalEnergy;
  }

  // Example of how to get various data types in one call
  Future<Map<HealthDataType, List<HealthDataPoint>>> getAllRequestedData(DateTime startDate, DateTime endDate) async {
    if (!_isAuthorized) {
      debugPrint("Health data not authorized. Please request authorization first.");
      bool authorized = await requestAuthorization();
      if (!authorized) return {};
    }
    
    Map<HealthDataType, List<HealthDataPoint>> allData = {};
    try {
      for (HealthDataType type in _dataTypes) {
        List<HealthDataPoint> points = await _health.getHealthDataFromTypes(startTime: startDate, endTime: endDate, types: [type]);
        allData[type] = points;
      }
    } catch (e) {
      debugPrint("Error fetching all requested health data: $e");
    }
    return allData;
  }
}
