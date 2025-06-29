import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class CloudFunctionService {
  // Initialize FirebaseFunctions instance, optionally specifying a region.
  // It's good practice to use the same region as your deployed functions.
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// Calls the 'generateMindForecast' Cloud Function.
  ///
  /// Returns a Map containing the forecast data (text, emoji, advice, etc.)
  /// or throws an HttpsCallableException if the call fails.
  Future<Map<String, dynamic>> getMindForecast() async {
    // Create a HttpsCallable instance for the function.
    final HttpsCallable callable = _functions.httpsCallable('generateMindForecast');

    try {
      // Call the function. You can pass parameters if your function expects any.
      // For 'generateMindForecast', we don't need to pass parameters from the client
      // as the userId is obtained from the authentication context on the server-side.
      final HttpsCallableResult result = await callable.call();
      
      // The result.data will be a Map<String, dynamic> if the function returns a JSON object.
      if (result.data is Map<String, dynamic>) {
        return result.data as Map<String, dynamic>;
      } else {
        // Handle unexpected data type from function if necessary
        debugPrint("Cloud function returned unexpected data type: ${result.data.runtimeType}"); // TODO: Use a proper logger or analytics in production
        throw Exception('Cloud function returned unexpected data format.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException calling getMindForecast: ${e.code} - ${e.message}'); // TODO: Use a proper logger or analytics in production
      // You might want to rethrow a more user-friendly error or handle specific codes
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling getMindForecast: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
  }

  /// Calls the 'getPharmacistAdvice' Cloud Function.
  /// 
  /// [query] The user's question about medication.
  /// [medicationContext] Optional list of current medication names for context.
  /// [chatHistory] Optional list of previous messages for context.
  /// Returns a Map containing the advice and disclaimer.
  Future<Map<String, dynamic>> getPharmacistAdvice({
    required String query,
    List<String>? medicationContext,
    List<Map<String, dynamic>>? chatHistory,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('getPharmacistAdvice');
    try {
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'query': query,
        'medicationContext': medicationContext,
        'chatHistory': chatHistory,
      });
      if (result.data is Map<String, dynamic>) {
        return result.data as Map<String, dynamic>;
      } else {
        debugPrint("Pharmacist advice function returned unexpected data type: ${result.data.runtimeType}"); // TODO: Use a proper logger or analytics in production
        throw Exception('Pharmacist advice function returned unexpected data format.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException calling getPharmacistAdvice: ${e.code} - ${e.message}'); // TODO: Use a proper logger or analytics in production
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling getPharmacistAdvice: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
  }

  /// Calls the 'getEmpatheticResponse' Cloud Function.
  ///
  /// [userMessage] The user's latest message.
  /// [chatHistory] Optional list of previous messages for context.
  /// Returns a Map containing the AI's empathetic response.
  Future<Map<String, dynamic>> getEmpatheticResponse({
    required String userMessage,
    List<Map<String, dynamic>>? chatHistory,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('getEmpatheticResponse');
    try {
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'userMessage': userMessage,
        'chatHistory': chatHistory,
      });
      if (result.data is Map<String, dynamic>) {
        return result.data as Map<String, dynamic>;
      } else {
        debugPrint("Empathetic response function returned unexpected data type: ${result.data.runtimeType}"); // TODO: Use a proper logger or analytics in production
        throw Exception('Empathetic response function returned unexpected data format.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException calling getEmpatheticResponse: ${e.code} - ${e.message}'); // TODO: Use a proper logger or analytics in production
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling getEmpatheticResponse: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
  }

  /// Calls the 'getCommunicationAdvice' Cloud Function.
  ///
  /// [situation] A description of the current situation the partner is facing.
  /// [partnerQuery] Optional specific question or concern from the partner.
  /// Returns a Map containing 'adviceText' and 'examplePhrases'.
  Future<Map<String, dynamic>> getCommunicationAdvice({
    required String situation,
    String? partnerQuery,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('getCommunicationAdvice');
    try {
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'situation': situation,
        'partnerQuery': partnerQuery,
      });
      if (result.data is Map<String, dynamic>) {
        // Ensure the returned data has the expected keys, even if null
        final Map<String, dynamic> data = result.data as Map<String, dynamic>;
        return {
          'adviceText': data['adviceText'],
          'examplePhrases': List<String>.from(data['examplePhrases'] ?? []),
        };
      } else {
        debugPrint("Communication advice function returned unexpected data type: ${result.data.runtimeType}"); // TODO: Use a proper logger or analytics in production
        throw Exception('Communication advice function returned unexpected data format.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException calling getCommunicationAdvice: ${e.code} - ${e.message}'); // TODO: Use a proper logger or analytics in production
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling getCommunicationAdvice: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }

  }

  /// Calls the 'getPartnerChatAdvice' Cloud Function for ongoing partner chat.
  ///
  /// [userMessage] The partner's latest message.
  /// [chatHistory] Optional list of previous messages for context.
  ///   Each map in the list should have 'role' (String) and 'parts' (List) keys.
  /// Returns a Map containing the AI's chat response (e.g., {'aiResponse': '...'}).
  Future<Map<String, dynamic>> getPartnerChatAdvice({
    required String userMessage,
    List<Map<String, dynamic>>? chatHistory,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('getPartnerChatAdvice');
    try {
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'userMessage': userMessage,
        'chatHistory': chatHistory, // This will be converted to the JS equivalent by the SDK
      });
      if (result.data is Map<String, dynamic>) {
        return result.data as Map<String, dynamic>;
      } else {
        debugPrint("Partner chat advice function returned unexpected data type: ${result.data.runtimeType}");
        throw Exception('Partner chat advice function returned unexpected data format.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException calling getPartnerChatAdvice: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling getPartnerChatAdvice: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> callHelloWorld() async {
    final HttpsCallable callable = _functions.httpsCallable('helloWorld');
    try {
      final HttpsCallableResult result = await callable.call();
      debugPrint("helloWorld call successful: ${result.data}");
      return result.data as Map<String, dynamic>;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException calling helloWorld: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling helloWorld: $e');
      rethrow;
    }
  }

  /// Calls the 'generateEmpatheticComment' Cloud Function.
  ///
  /// [diaryText] The user's diary text.
  /// Returns a Map containing the AI's empathetic comment (e.g., {'comment': '...'}).
  Future<Map<String, dynamic>> generateEmpatheticComment({
    required String diaryText,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('generateEmpatheticComment');
    try {
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'diaryText': diaryText,
      });
      if (result.data is Map<String, dynamic>) {
        return result.data as Map<String, dynamic>;
      } else {
        debugPrint("generateEmpatheticComment function returned unexpected data type: ${result.data.runtimeType}");
        throw Exception('generateEmpatheticComment function returned unexpected data format.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException calling generateEmpatheticComment: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling generateEmpatheticComment: $e');
      rethrow;
    }
  }

  /// Calls the 'generateEmpatheticCommentAndRecord' Cloud Function.
  ///
  /// [selfReportedMoodScore] The user's mood score (1-5).
  /// [diaryText] The user's diary text (optional).
  /// [selectedEvents] The list of selected event IDs (optional).
  /// [sleepDurationHours] The sleep duration in hours (optional).
  /// [weatherData] The weather data (optional).
  /// Returns a Map containing the result of the operation (e.g., success, logId, aiComment).
  Future<Map<String, dynamic>> generateAndSaveDiaryLogWithComment({
    required int selfReportedMoodScore,
    String? diaryText,
    List<String>? selectedEvents,
    double? sleepDurationHours,
    dynamic weatherData, // WeatherDataモデルのtoMap()結果
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('generateEmpatheticCommentAndRecord');
    try {
      final Map<String, dynamic> payload = {
        'selfReportedMoodScore': selfReportedMoodScore,
        'diaryText': diaryText,
        'selectedEvents': selectedEvents,
      };
      
      // 睡眠時間データを追加
      if (sleepDurationHours != null) {
        payload['sleepDurationHours'] = sleepDurationHours;
      }
      
      // 天気データを追加
      if (weatherData != null) {
        payload['weatherData'] = weatherData is Map ? weatherData : weatherData.toMap();
      }

      final HttpsCallableResult result = await callable.call(payload);
      if (result.data is Map<String, dynamic>) {
        return result.data as Map<String, dynamic>;
      } else {
        debugPrint("generateEmpatheticCommentAndRecord function returned unexpected data type: ${result.data.runtimeType}");
        throw Exception('generateEmpatheticCommentAndRecord function returned unexpected data format.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException calling generateEmpatheticCommentAndRecord: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling generateEmpatheticCommentAndRecord: $e');
      rethrow;
    }
  }

  /// Calls the 'getPartnerWeatherForecast' Cloud Function.
  ///
  /// [partnerId] The ID of the partner whose weather forecast to get.
  /// Returns a String containing the weather forecast text.
  Future<String> getPartnerWeatherForecast(String partnerId) async {
    final HttpsCallable callable = _functions.httpsCallable('generateMindForecast');
    try {
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'targetUserId': partnerId,
      });
      if (result.data is Map<String, dynamic>) {
        final data = result.data as Map<String, dynamic>;
        return data['forecastText'] ?? 'データがありません';
      } else {
        debugPrint("getPartnerWeatherForecast function returned unexpected data type: ${result.data.runtimeType}");
        throw Exception('getPartnerWeatherForecast function returned unexpected data format.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException calling getPartnerWeatherForecast: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling getPartnerWeatherForecast: $e');
      rethrow;
    }
  }

  /// Calls the 'getMentalHints' Cloud Function.
  ///
  /// Returns a Map containing the hints data (hints array, analyzedPeriod, totalLogs).
  Future<Map<String, dynamic>> getMentalHints() async {
    final HttpsCallable callable = _functions.httpsCallable('getMentalHints');
    try {
      final HttpsCallableResult result = await callable.call();
      if (result.data is Map<String, dynamic>) {
        return result.data as Map<String, dynamic>;
      } else {
        debugPrint("getMentalHints function returned unexpected data type: ${result.data.runtimeType}");
        throw Exception('getMentalHints function returned unexpected data format.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException calling getMentalHints: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling getMentalHints: $e');
      rethrow;
    }
  }
}
