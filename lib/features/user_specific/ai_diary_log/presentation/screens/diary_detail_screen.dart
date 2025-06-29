import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../models/ai_diary_log_model.dart';
import '../../../../../models/daily_event_model.dart';
import '../../../../../services/custom_event_service.dart';
import 'diary_edit_screen.dart';

class DiaryDetailScreen extends StatefulWidget {
  final AiDiaryLog diaryLog;

  const DiaryDetailScreen({
    super.key,
    required this.diaryLog,
  });

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<DailyEvent> _allEvents = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await CustomEventService.getAllEvents();
    setState(() {
      _allEvents = events;
    });
  }

  List<DailyEvent> _getSelectedEvents() {
    if (widget.diaryLog.selectedEvents == null || widget.diaryLog.selectedEvents!.isEmpty) {
      return [];
    }
    
    return _allEvents
        .where((event) => widget.diaryLog.selectedEvents!.contains(event.id))
        .toList();
  }

  Future<void> _deleteDiary() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('日記を削除'),
        content: const Text('この日記を削除しますか？この操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('aiDiaryLogs')
              .doc(widget.diaryLog.logId)
              .delete();
          
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('日記を削除しました')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e')),
          );
        }
      }
    }
  }

  void _editDiary() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryEditScreen(diaryLog: widget.diaryLog),
      ),
    );
    
    if (result == true) {
      // 編集が完了したら画面を閉じる
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _getSelectedEvents();
    final dateFormat = DateFormat('yyyy年M月d日(E)', 'ja_JP');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('日記詳細'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editDiary,
            tooltip: '編集',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deleteDiary();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('削除', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日付・時刻
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          '記録日時',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateFormat.format(widget.diaryLog.timestamp.toDate()),
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      timeFormat.format(widget.diaryLog.timestamp.toDate()),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 気分スコア
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mood, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          '気分スコア',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${widget.diaryLog.selfReportedMoodScore}/5',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _getMoodIcon(widget.diaryLog.selfReportedMoodScore),
                          color: _getMoodColor(widget.diaryLog.selfReportedMoodScore),
                          size: 28,
                        ),
                      ],
                    ),
                    Text(
                      _getMoodDescription(widget.diaryLog.selfReportedMoodScore),
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 睡眠時間
            if (widget.diaryLog.sleepDurationHours != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bedtime, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            '睡眠時間',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${widget.diaryLog.sleepDurationHours!.toStringAsFixed(1)}時間',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _getSleepIcon(widget.diaryLog.sleepDurationHours!),
                            color: _getSleepColor(widget.diaryLog.sleepDurationHours!),
                            size: 24,
                          ),
                        ],
                      ),
                      Text(
                        _getSleepDescription(widget.diaryLog.sleepDurationHours!),
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 天気情報
            if (widget.diaryLog.weatherData != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wb_sunny, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            '天気',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            widget.diaryLog.weatherData!.description,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${widget.diaryLog.weatherData!.temperatureCelsius.round()}°C',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (widget.diaryLog.weatherData!.humidity != null || 
                          widget.diaryLog.weatherData!.pressureHPa != null)
                        Row(
                          children: [
                            if (widget.diaryLog.weatherData!.humidity != null) ...[
                              Icon(Icons.water_drop, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                '湿度 ${widget.diaryLog.weatherData!.humidity!.round()}%',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            if (widget.diaryLog.weatherData!.humidity != null && 
                                widget.diaryLog.weatherData!.pressureHPa != null)
                              const SizedBox(width: 16),
                            if (widget.diaryLog.weatherData!.pressureHPa != null) ...[
                              Icon(Icons.speed, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '気圧 ${widget.diaryLog.weatherData!.pressureHPa!.round()}hPa',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),

            // 選択されたイベント
            if (selectedEvents.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            '今日の出来事',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedEvents.map((event) {
                          return Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(event.emoji, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                                Text(event.label),
                              ],
                            ),
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            side: BorderSide(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            // 日記内容
            if (widget.diaryLog.diaryText != null && widget.diaryLog.diaryText!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.article, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            '日記',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.diaryLog.diaryText!,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // AIコメント
            if (widget.diaryLog.aiComment != null && widget.diaryLog.aiComment!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'AIからのコメント',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          widget.diaryLog.aiComment!,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getMoodIcon(int score) {
    switch (score) {
      case 5:
        return Icons.sentiment_very_satisfied;
      case 4:
        return Icons.sentiment_satisfied;
      case 3:
        return Icons.sentiment_neutral;
      case 2:
        return Icons.sentiment_dissatisfied;
      case 1:
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  Color _getMoodColor(int score) {
    switch (score) {
      case 5:
        return Colors.green;
      case 4:
        return Colors.lightGreen;
      case 3:
        return Colors.orange;
      case 2:
        return Colors.deepOrange;
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getMoodDescription(int score) {
    switch (score) {
      case 5:
        return 'とても良い状態です';
      case 4:
        return '良い状態です';
      case 3:
        return '普通の状態です';
      case 2:
        return '少し不調です';
      case 1:
        return '不調です';
      default:
        return '不明';
    }
  }

  IconData _getSleepIcon(double hours) {
    if (hours >= 7 && hours <= 9) {
      return Icons.check_circle;
    } else if (hours >= 6 && hours < 7) {
      return Icons.schedule;
    } else if (hours > 9) {
      return Icons.snooze;
    } else {
      return Icons.warning;
    }
  }

  Color _getSleepColor(double hours) {
    if (hours >= 7 && hours <= 9) {
      return Colors.green;
    } else if (hours >= 6 && hours < 7) {
      return Colors.orange;
    } else if (hours > 9) {
      return Colors.blue;
    } else {
      return Colors.red;
    }
  }

  String _getSleepDescription(double hours) {
    if (hours >= 7 && hours <= 9) {
      return '理想的な睡眠時間です';
    } else if (hours >= 6 && hours < 7) {
      return 'やや短い睡眠時間です';
    } else if (hours > 9) {
      return '長めの睡眠時間です';
    } else {
      return '睡眠不足の可能性があります';
    }
  }
}