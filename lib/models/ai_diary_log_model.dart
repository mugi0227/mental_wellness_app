import 'package:cloud_firestore/cloud_firestore.dart';
import 'weather_data_model.dart';

class AiDiaryLog {
  final String? id;
  final String? logId; // Firestore document ID for updates/deletes
  final String userId;
  final Timestamp timestamp;
  final int selfReportedMoodScore; // 1-5の自己申告気分スコア
  final String diaryText; // 日記本文 (空の場合もある)
  final List<String> selectedEvents; // 選択されたイベントのIDリスト（独立カラム）
  final double? sleepDurationHours; // 睡眠時間（時間）（独立カラム）
  final WeatherData? weatherData; // 天気データ（独立カラム）
  final double? aiAnalyzedPositivityScore; // AIによるポジティブ度スコア
  final double? overallMoodScore; // 総合気分スコア
  final String? aiComment; // AIからの共感的コメント

  AiDiaryLog({
    this.id,
    this.logId,
    required this.userId,
    required this.timestamp,
    required this.selfReportedMoodScore,
    required this.diaryText,
    this.selectedEvents = const [], // デフォルトは空リスト
    this.sleepDurationHours,
    this.weatherData,
    this.aiAnalyzedPositivityScore,
    this.overallMoodScore,
    this.aiComment,
  });

  factory AiDiaryLog.fromMap(Map<String, dynamic> data, String documentId) {
    return AiDiaryLog(
      id: documentId,
      logId: documentId, // logIdはdocumentIdと同じ
      userId: data['userId'] as String,
      timestamp: data['timestamp'] as Timestamp,
      selfReportedMoodScore: data['selfReportedMoodScore'] as int,
      diaryText: data['diaryText'] as String? ?? '', // FirestoreにdiaryTextがない場合は空文字
      selectedEvents: (data['selectedEvents'] as List?)?.cast<String>() ?? [],
      sleepDurationHours: (data['sleepDurationHours'] as num?)?.toDouble(),
      weatherData: data['weatherData'] != null 
          ? WeatherData.fromMap(data['weatherData'] as Map<String, dynamic>)
          : null,
      aiAnalyzedPositivityScore: (data['aiAnalyzedPositivityScore'] as num?)?.toDouble(),
      overallMoodScore: (data['overallMoodScore'] as num?)?.toDouble(),
      aiComment: data['aiComment'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'timestamp': timestamp,
      'selfReportedMoodScore': selfReportedMoodScore,
      'diaryText': diaryText,
      'selectedEvents': selectedEvents, // 常に保存（空リストでも）
      if (sleepDurationHours != null) 'sleepDurationHours': sleepDurationHours,
      if (weatherData != null) 'weatherData': weatherData!.toMap(),
      if (aiAnalyzedPositivityScore != null) 'aiAnalyzedPositivityScore': aiAnalyzedPositivityScore,
      if (overallMoodScore != null) 'overallMoodScore': overallMoodScore,
      if (aiComment != null) 'aiComment': aiComment,
    };
  }
}
