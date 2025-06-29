import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:cloud_functions/cloud_functions.dart'; // For FirebaseFunctionsException
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestampのためにインポート
import 'package:mental_wellness_app/models/ai_diary_log_model.dart'; // MoodLogモデルをインポート
// import 'package:mental_wellness_app/services/firestore_service.dart'; // Firestoreサービスは直接使わなくなるためコメントアウトまたは削除
import 'package:mental_wellness_app/screens/partner_link_screen.dart';
import 'package:mental_wellness_app/screens/calendar_screen.dart'; // カレンダー画面をインポート
import 'package:mental_wellness_app/features/user_specific/medication_tracker/presentation/screens/medication_list_screen.dart'; // お薬リスト画面をインポート
import 'package:mental_wellness_app/features/user_specific/medication_tracker/presentation/screens/pharmacist_chat_screen.dart'; // 薬剤師チャット画面
import 'package:mental_wellness_app/services/cloud_function_service.dart'; // Cloud Functionsサービスをインポート
import 'package:mental_wellness_app/features/user_specific/mood_graph/presentation/screens/mood_graph_screen.dart'; // 気分グラフ画面
import 'package:mental_wellness_app/features/user_specific/health_data/presentation/screens/health_data_screen.dart'; // ヘルスデータ画面
import 'package:mental_wellness_app/screens/empathetic_chat_screen.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';
import 'package:mental_wellness_app/models/daily_event_model.dart';
import 'package:mental_wellness_app/services/custom_event_service.dart';
import 'package:mental_wellness_app/services/health_service.dart';
import 'package:mental_wellness_app/services/weather_service.dart';
import 'package:mental_wellness_app/models/weather_data_model.dart';
import 'package:mental_wellness_app/widgets/add_custom_event_dialog.dart';
import 'package:mental_wellness_app/features/user_specific/mental_hints/screens/mental_hints_screen.dart';

class AiDiaryLogScreen extends StatefulWidget {
  const AiDiaryLogScreen({super.key});

  @override
  State<AiDiaryLogScreen> createState() => _AiDiaryLogScreenState();
}

class _AiDiaryLogScreenState extends State<AiDiaryLogScreen> {
  // final FirestoreService _firestoreService = FirestoreService(); // 直接使わなくなる
  final CloudFunctionService _cloudFunctionService = CloudFunctionService(); // CloudFunctionServiceのインスタンス
  // HealthServiceは静的メソッドを使用するためインスタンス不要
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _diaryController = TextEditingController();


  int _selectedMood = 3; // 1-5の評価、デフォルトは「普通」
  bool _isLoading = false; // 保存処理中のローディング状態を管理
  List<String> _selectedEvents = []; // 選択されたイベントのIDリスト
  List<DailyEvent> _allEvents = []; // 全イベント（定義済み + カスタム）
  
  // 今日のデータ情報
  double? _todaySleepHours;
  String? _todayWeatherInfo;
  String? _todayWeatherError;
  bool _isLoadingTodayData = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadTodayData(); // 今日のデータを読み込み
  }

  Future<void> _loadEvents() async {
    final events = await CustomEventService.getAllEvents();
    setState(() {
      _allEvents = events;
    });
  }


  @override
  void dispose() {
    _diaryController.dispose();
    super.dispose();
  }

  Future<void> _saveMoodLog() async {
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしていません。')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // 睡眠時間と天気データを並行取得
      final today = DateTime.now();
      final sleepDataFuture = _getSleepDuration(today);
      final weatherDataFuture = _getWeatherData();

      final sleepDuration = await sleepDataFuture;
      final weatherData = await weatherDataFuture;

      // 新しい構造化データでAiDiaryLogを作成
      final diaryLog = AiDiaryLog(
        userId: user.uid,
        timestamp: Timestamp.fromDate(today),
        selfReportedMoodScore: _selectedMood,
        diaryText: _diaryController.text.trim(),
        selectedEvents: _selectedEvents,
        sleepDurationHours: sleepDuration,
        weatherData: weatherData,
      );

      // Cloud Function呼び出し（新しい構造化データ対応）
      final result = await _cloudFunctionService.generateAndSaveDiaryLogWithComment(
        selfReportedMoodScore: _selectedMood,
        diaryText: _diaryController.text.trim(),
        selectedEvents: _selectedEvents,
        sleepDurationHours: sleepDuration,
        weatherData: weatherData?.toMap(),
      );

      if (result['success'] == true) {
        // final aiComment = result['aiComment'] as String?; // コメントはここで表示しない
        String successMessage = '気分を記録しました！';
        // if (aiComment != null && aiComment.isNotEmpty) {
        //   successMessage += ' AIからのコメントも保存されました。';
        // } else if (_diaryController.text.isNotEmpty) {
        //  // successMessage += ' AIコメントの生成に失敗したか、コメントがありませんでした。';
        // }

        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(successMessage)),
        );

        _diaryController.clear();
        setState(() {
          _selectedMood = 3;
          _selectedEvents.clear(); // 選択されたイベントもクリア
        });
 
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(result['error'] as String? ?? '日記の記録に失敗しました。')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('エラー (Code: ${e.code}): ${e.message}')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('予期せぬエラーが発生しました: $e')),
      );
    } finally {
      if (mounted) { // Ensure the widget is still in the tree
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 今日の睡眠時間を取得（時間単位）
  Future<double?> _getSleepDuration(DateTime date) async {
    try {
      // 前日の夜から当日の朝までの睡眠データを取得
      final startDate = DateTime(date.year, date.month, date.day - 1, 20, 0); // 前日20時から
      final endDate = DateTime(date.year, date.month, date.day, 12, 0); // 当日12時まで
      
      return await HealthService.getSleepData(startDate, endDate);
    } catch (e) {
      print('睡眠データ取得エラー: $e');
    }
    return null;
  }

  /// 現在地の天気データを取得
  Future<WeatherData?> _getWeatherData() async {
    try {
      if (_weatherService.isApiKeyConfigured) {
        return await _weatherService.getCurrentWeather();
      } else {
        print('天気APIキーが設定されていません');
      }
    } catch (e) {
      print('天気データ取得エラー: $e');
    }
    return null;
  }

  /// 今日のデータ（睡眠・天気）を読み込み
  Future<void> _loadTodayData() async {
    setState(() {
      _isLoadingTodayData = true;
    });

    try {
      final today = DateTime.now();
      
      // 睡眠時間と天気データを並行取得
      final futures = await Future.wait([
        _getSleepDuration(today),
        _getWeatherData(),
      ]);
      
      final sleepHours = futures[0] as double?;
      final weatherData = futures[1] as WeatherData?;
      
      setState(() {
        _todaySleepHours = sleepHours;
        _todayWeatherInfo = weatherData != null 
            ? '${weatherData.description} ${weatherData.temperatureCelsius.round()}°C${weatherData.cityName != null ? ' (${weatherData.cityName})' : ''}'
            : null;
        _todayWeatherError = weatherData == null ? '天気情報を取得できませんでした' : null;
        _isLoadingTodayData = false;
      });
    } catch (e) {
      print('今日のデータ読み込みエラー: $e');
      setState(() {
        _todayWeatherError = '取得エラー: ${e.toString()}';
        _isLoadingTodayData = false;
      });
    }
  }

  String? _combineDiaryText(String? eventsText) {
    final diaryText = _diaryController.text.trim();
    if (eventsText != null && eventsText.isNotEmpty) {
      if (diaryText.isNotEmpty) {
        return '$diaryText\n\n今日の出来事: $eventsText';
      } else {
        return '今日の出来事: $eventsText';
      }
    } else if (diaryText.isNotEmpty) {
      return diaryText;
    }
    return null; // 何も入力されていない場合
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => AddCustomEventDialog(
        onEventAdded: (event) async {
          await CustomEventService.saveCustomEvent(event);
          await _loadEvents(); // イベントリストを再読み込み
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「${event.label}」を追加しました！')),
          );
        },
      ),
    );
  }

  void _showDeleteEventDialog(DailyEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('カスタムイベントを削除'),
        content: Text('「${event.emoji} ${event.label}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              await CustomEventService.deleteCustomEvent(event.id);
              _selectedEvents.remove(event.id); // 選択からも削除
              await _loadEvents(); // イベントリストを再読み込み
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('「${event.label}」を削除しました')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'タップして今日の出来事を記録しよう！',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => _showAddEventDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: AppTheme.primaryColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'カスタム追加',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '⭐ カスタムイベントは長押しで削除できます',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allEvents.map((event) {
              final isSelected = _selectedEvents.contains(event.id);
              final isCustom = event.id.startsWith('custom_');
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedEvents.remove(event.id);
                    } else {
                      _selectedEvents.add(event.id);
                    }
                  });
                },
                onLongPress: isCustom ? () => _showDeleteEventDialog(event) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : (isCustom 
                            ? Colors.blue.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? AppTheme.primaryColor
                          : (isCustom 
                              ? Colors.blue.withValues(alpha: 0.4)
                              : Colors.grey.withValues(alpha: 0.3)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        event.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondaryColor,
                        ),
                      ),
                      if (isCustom) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.blue.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0), // 喫茶店のような温かみのある背景色
      appBar: AppBar(
        title: const Text(
          '日記',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 22),
            tooltip: 'カレンダー',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.monitor_heart_outlined, size: 22),
            tooltip: 'ヘルスデータ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HealthDataScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, size: 22),
            tooltip: '心のヒント',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MentalHintsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 今日のデータ表示
                if (_todaySleepHours != null || _todayWeatherInfo != null || _todayWeatherError != null || _isLoadingTodayData)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.today,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '今日のデータ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        if (_isLoadingTodayData) ...[
                          const SizedBox(height: 8),
                          Text(
                            '取得中...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (_todaySleepHours != null) ...[
                                Icon(Icons.bedtime, size: 14, color: Colors.purple),
                                const SizedBox(width: 4),
                                Text(
                                  '睡眠 ${_todaySleepHours!.toStringAsFixed(1)}h',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ] else ...[
                                Icon(Icons.bedtime, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '睡眠データなし',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                              const SizedBox(width: 16),
                              if (_todayWeatherInfo != null) ...[
                                Icon(Icons.wb_sunny, size: 14, color: Colors.orange),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _todayWeatherInfo!,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ] else if (_todayWeatherError != null) ...[
                                Icon(Icons.cloud_off, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _todayWeatherError!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              ] else ...[
                                Icon(Icons.wb_sunny, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '天気データなし',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                
                Text(
              '今日の気分はどうですか？',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (index) {
                final moodLevel = index + 1;
                IconData iconData;
                Color iconColor;
                String tooltip;

                switch (moodLevel) {
                  case 1:
                    iconData = Icons.sentiment_very_dissatisfied;
                    iconColor = const Color(0xFFD32F2F); // 落ち着いた赤
                    tooltip = '最悪';
                    break;
                  case 2:
                    iconData = Icons.sentiment_dissatisfied;
                    iconColor = const Color(0xFFF57C00); // 落ち着いたオレンジ
                    tooltip = '悪い';
                    break;
                  case 3:
                    iconData = Icons.sentiment_neutral;
                    iconColor = const Color(0xFF689F38); // ライトグリーン
                    tooltip = '普通';
                    break;
                  case 4:
                    iconData = Icons.sentiment_satisfied;
                    iconColor = const Color(0xFF388E3C); // グリーン
                    tooltip = '良い';
                    break;
                  case 5:
                    iconData = Icons.sentiment_very_satisfied;
                    iconColor = const Color(0xFF2E7D32); // 深い緑
                    tooltip = '最高';
                    break;
                  default:
                    iconData = Icons.help;
                    iconColor = Colors.black;
                    tooltip = '';
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = moodLevel;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: _selectedMood == moodLevel
                                ? RadialGradient(
                                    colors: [
                                      iconColor.withValues(alpha: 0.3),
                                      iconColor.withValues(alpha: 0.1),
                                    ],
                                  )
                                : null,
                            color: _selectedMood == moodLevel
                                ? null
                                : Colors.grey.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedMood == moodLevel
                                  ? iconColor
                                  : Colors.grey.withValues(alpha: 0.2),
                              width: _selectedMood == moodLevel ? 3 : 1,
                            ),
                            boxShadow: _selectedMood == moodLevel
                                ? [
                                    BoxShadow(
                                      color: iconColor.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            iconData,
                            size: 36,
                            color: _selectedMood == moodLevel
                                ? iconColor
                                : AppTheme.textTertiaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tooltip,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _selectedMood == moodLevel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedMood == moodLevel
                                ? iconColor
                                : AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // 今日の出来事選択セクション
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.event_note, color: AppTheme.primaryColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '今日の出来事',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            _buildEventSelection(),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.edit_note, color: AppTheme.primaryColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '日記を書く',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 200, // 固定の高さを設定
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _diaryController,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimaryColor,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '今日あったことや感じたことを自由に書きましょう...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.all(20),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 120), // キャラクターと重ならないように余白をさらに追加
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                onPressed: _isLoading ? null : _saveMoodLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            '記録する',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                ),
              ),
            ),
              ],
            ),
          ),
    );
  }
}
