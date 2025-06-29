import 'package:flutter/foundation.dart'; // Required for debugPrint and kIsWeb
import 'health_service_stub.dart'
    if (dart.library.io) 'health_service_mobile.dart'
    if (dart.library.html) 'health_service_web.dart';

class HealthService {
  static dynamic _health;
  static bool _isAuthorized = false;
  
  static void _initializeHealth() {
    if (!kIsWeb) {
      _health = getHealthInstance();
    }
  }

  // Define the data types you want to access
  static List<dynamic> get _dataTypes {
    if (kIsWeb) return [];
    return getHealthDataTypes();
  }

  static Future<bool> checkHealthPermissions() async {
    if (kIsWeb) {
      debugPrint('Health permissions not available on Web');
      return false;
    }
    
    try {
      final types = isIOS() 
          ? [getSleepAsleepType()]
          : [getSleepSessionType()];
      
      return await hasHealthPermissions(_health, types) ?? false;
    } catch (e) {
      debugPrint('Error checking health permissions: $e');
      return false;
    }
  }

  static Future<bool> requestHealthPermissions() async {
    if (kIsWeb) {
      debugPrint('Health permissions not available on Web');
      return false;
    }
    
    try {
      final types = isIOS() 
          ? [getSleepAsleepType()]
          : [getSleepSessionType()];
      
      final permissions = [getReadPermission()];
      
      return await requestHealthAuthorization(_health, types, permissions);
    } catch (e) {
      debugPrint('Error requesting health permissions: $e');
      return false;
    }
  }

  /// Requests authorization to access health data.
  /// Returns true if authorization is granted, false otherwise.
  Future<bool> requestAuthorization() async {
    if (_isAuthorized) return true;
    if (kIsWeb) {
      debugPrint('Health authorization not available on Web');
      return false;
    }
    
    _initializeHealth();

    // Request authorization for all defined types
    // The HealthFactory constructor has an optional types parameter, 
    // but requestAuthorization is preferred for clarity and dynamic requests.
    // For Health Connect, specific permissions need to be declared in AndroidManifest.xml
    // For HealthKit, usage descriptions (NSHealthShareUsageDescription, NSHealthUpdateUsageDescription)
    // need to be added to Info.plist.
    try {
      _isAuthorized = await requestHealthAuthorizationForTypes(_health, _dataTypes);
      return _isAuthorized;
    } catch (e) {
      debugPrint("Error requesting health authorization: $e");
      return false;
    }
  }

  static Future<double?> getSleepData(DateTime startDate, DateTime endDate) async {
    if (kIsWeb) {
      debugPrint('Sleep data not available on Web');
      return null;
    }
    
    try {
      final types = isIOS()
          ? [getSleepAsleepType()]
          : [getSleepSessionType()];
      
      final healthData = await getHealthDataFromTypes(
        _health,
        startDate,
        endDate,
        types,
      );
      
      if (healthData.isEmpty) return null;
      
      double totalMinutes = 0;
      for (final point in healthData) {
        final numericValue = getNumericHealthValue(point);
        if (numericValue != null) {
          totalMinutes += numericValue;
        }
      }
      
      return totalMinutes / 60; // Convert to hours
    } catch (e) {
      debugPrint('Error fetching sleep data: $e');
      return null;
    }
  }

  /// Fetches sleep data for the given date range.
  Future<List<dynamic>> getSleepDataPoints(DateTime startDate, DateTime endDate) async {
    if (!_isAuthorized) {
      debugPrint("Health data not authorized. Please request authorization first.");
      bool authorized = await requestAuthorization();
      if (!authorized) return [];
    }

    List<dynamic> sleepData = [];
    try {
      // Fetch sleep data (asleep duration)
      List<dynamic> asleep = await getHealthDataFromTypes(
        _health,
        startDate,
        endDate,
        [getSleepAsleepType()],
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
      List<dynamic> stepsData = await getHealthDataFromTypes(
        _health,
        startDate,
        endDate,
        [getStepsType()],
      );
      for (var dataPoint in stepsData) {
        final numericValue = getNumericHealthValue(dataPoint);
        if (numericValue != null) {
          totalSteps += numericValue.toInt();
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
      List<dynamic> energyData = await getHealthDataFromTypes(
        _health,
        startDate,
        endDate,
        [getActiveEnergyType()],
      );
      for (var dataPoint in energyData) {
        final numericValue = getNumericHealthValue(dataPoint);
        if (numericValue != null) {
          totalEnergy += numericValue;
        }
      }
    } catch (e) {
      debugPrint("Error fetching active energy data: $e");
    }
    return totalEnergy;
  }

  // Example of how to get various data types in one call
  Future<Map<dynamic, List<dynamic>>> getAllRequestedData(DateTime startDate, DateTime endDate) async {
    if (!_isAuthorized) {
      debugPrint("Health data not authorized. Please request authorization first.");
      bool authorized = await requestAuthorization();
      if (!authorized) return {};
    }
    
    Map<dynamic, List<dynamic>> allData = {};
    try {
      for (dynamic type in _dataTypes) {
        List<dynamic> points = await getHealthDataFromTypes(_health, startDate, endDate, [type]);
        allData[type] = points;
      }
    } catch (e) {
      debugPrint("Error fetching all requested health data: $e");
    }
    return allData;
  }
}
