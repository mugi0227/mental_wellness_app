import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/weather_data_model.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  
  static String get _apiKey {
    return dotenv.env['OPENWEATHERMAP_API_KEY'] ?? 'YOUR_OPENWEATHERMAP_API_KEY';
  }

  /// 現在地の天気情報を取得
  Future<WeatherData?> getCurrentWeather() async {
    try {
      // 位置情報の取得
      final position = await _getCurrentPosition();
      if (position == null) return null;

      // OpenWeatherMap API呼び出し
      final url = Uri.parse(
        '$_baseUrl?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric&lang=ja'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseWeatherData(data);
      } else {
        print('Weather API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting weather data: $e');
      return null;
    }
  }

  /// 指定した座標の天気情報を取得
  Future<WeatherData?> getWeatherByCoordinates(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=ja'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseWeatherData(data);
      } else {
        print('Weather API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting weather data: $e');
      return null;
    }
  }

  /// 位置情報を取得
  Future<Position?> _getCurrentPosition() async {
    try {
      // 位置情報サービスが有効かチェック
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return null;
      }

      // 位置情報権限をチェック
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      // 現在位置を取得
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  /// OpenWeatherMapのレスポンスからWeatherDataを作成
  WeatherData _parseWeatherData(Map<String, dynamic> data) {
    final main = data['main'] as Map<String, dynamic>;
    final weather = (data['weather'] as List).first as Map<String, dynamic>;
    final coord = data['coord'] as Map<String, dynamic>?;

    return WeatherData(
      description: weather['description'] as String,
      temperatureCelsius: (main['temp'] as num).toDouble(),
      pressureHPa: (main['pressure'] as num?)?.toDouble(),
      humidity: (main['humidity'] as num?)?.toDouble(),
      icon: weather['icon'] as String?,
      timestamp: DateTime.now(),
      latitude: coord != null ? (coord['lat'] as num?)?.toDouble() : null,
      longitude: coord != null ? (coord['lon'] as num?)?.toDouble() : null,
      cityName: data['name'] as String?,
    );
  }

  /// APIキーが設定されているかチェック
  bool get isApiKeyConfigured => _apiKey != 'YOUR_OPENWEATHERMAP_API_KEY';
}