import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/daily_event_model.dart';

class CustomEventService {
  static const String _customEventsKey = 'custom_events';
  
  // カスタムイベントを保存
  static Future<void> saveCustomEvent(DailyEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final customEvents = await getCustomEvents();
    customEvents.add(event);
    
    final jsonList = customEvents.map((e) => {
      'id': e.id,
      'label': e.label,
      'emoji': e.emoji,
      'category': e.category,
      'isPositive': e.isPositive,
    }).toList();
    
    await prefs.setString(_customEventsKey, json.encode(jsonList));
  }
  
  // カスタムイベントを取得
  static Future<List<DailyEvent>> getCustomEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_customEventsKey);
    
    if (jsonString == null) return [];
    
    final jsonList = json.decode(jsonString) as List;
    return jsonList.map((json) => DailyEvent(
      id: json['id'],
      label: json['label'],
      emoji: json['emoji'],
      category: json['category'],
      isPositive: json['isPositive'],
    )).toList();
  }
  
  // カスタムイベントを削除
  static Future<void> deleteCustomEvent(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final customEvents = await getCustomEvents();
    customEvents.removeWhere((event) => event.id == eventId);
    
    final jsonList = customEvents.map((e) => {
      'id': e.id,
      'label': e.label,
      'emoji': e.emoji,
      'category': e.category,
      'isPositive': e.isPositive,
    }).toList();
    
    await prefs.setString(_customEventsKey, json.encode(jsonList));
  }
  
  // すべてのイベント（定義済み + カスタム）を取得
  static Future<List<DailyEvent>> getAllEvents() async {
    final customEvents = await getCustomEvents();
    return [...DailyEvent.predefinedEvents, ...customEvents];
  }
}