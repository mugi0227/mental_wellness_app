class WeatherData {
  final String description; // 天気の説明 (e.g., "晴れ", "雨")
  final double temperatureCelsius; // 気温（摂氏）
  final double? pressureHPa; // 気圧（hPa）
  final double? humidity; // 湿度（%）
  final String? icon; // 天気アイコンコード
  final DateTime timestamp; // 取得時刻
  final double? latitude; // 緯度
  final double? longitude; // 経度
  final String? cityName; // 都市名

  WeatherData({
    required this.description,
    required this.temperatureCelsius,
    this.pressureHPa,
    this.humidity,
    this.icon,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.cityName,
  });

  factory WeatherData.fromMap(Map<String, dynamic> data) {
    return WeatherData(
      description: data['description'] as String,
      temperatureCelsius: (data['temperatureCelsius'] as num).toDouble(),
      pressureHPa: (data['pressureHPa'] as num?)?.toDouble(),
      humidity: (data['humidity'] as num?)?.toDouble(),
      icon: data['icon'] as String?,
      timestamp: data['timestamp'] is String 
          ? DateTime.parse(data['timestamp'])
          : (data['timestamp'] as dynamic).toDate(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      cityName: data['cityName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'temperatureCelsius': temperatureCelsius,
      if (pressureHPa != null) 'pressureHPa': pressureHPa,
      if (humidity != null) 'humidity': humidity,
      if (icon != null) 'icon': icon,
      'timestamp': timestamp.toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (cityName != null) 'cityName': cityName,
    };
  }

  @override
  String toString() {
    return '${description}, ${temperatureCelsius.round()}°C${cityName != null ? ' ($cityName)' : ''}${pressureHPa != null ? ', ${pressureHPa!.round()}hPa' : ''}';
  }
}