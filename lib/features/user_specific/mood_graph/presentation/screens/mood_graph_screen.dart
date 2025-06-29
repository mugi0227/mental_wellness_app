import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mental_wellness_app/models/ai_diary_log_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:collection/collection.dart'; // For groupBy
import 'package:mental_wellness_app/features/user_specific/ai_diary_log/presentation/screens/ai_diary_log_detail_screen.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';
// import 'package:mental_wellness_app/services/cloud_function_service.dart'; // 現在未使用

class MoodGraphScreen extends StatefulWidget {
  final String? userId; // 特定のユーザーのグラフを表示する場合
  final bool isViewOnly; // サポーターが閲覧する場合はtrue
  final Function(String)? onForecastMessageChanged; // メッセージ変更コールバック
  
  const MoodGraphScreen({
    super.key,
    this.userId,
    this.isViewOnly = false,
    this.onForecastMessageChanged,
  });

  @override
  State<MoodGraphScreen> createState() => _MoodGraphScreenState();
}

class _MoodGraphScreenState extends State<MoodGraphScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  // CloudFunctionServiceは現在使用していないのでコメントアウト
  // final CloudFunctionService _cloudFunctionService = CloudFunctionService();
  User? _currentUser;
  List<AiDiaryLog> _allMoodLogs = [];
  List<FlSpot> _chartSpots = [];
  List<String> _bottomTitles = [];
  List<DateTime> _spotDates = []; // Store actual dates for spots for tooltip/drilldown

  bool _isLoading = true;
  String _selectedPeriod = '日別'; // 日別, 週別, 月別
  final int _dailyLimit = 30; // Max 30 days for daily view
  final int _weeklyLimit = 12; // Max 12 weeks for weekly view
  final int _monthlyLimit = 12; // Max 12 months for monthly view
  
  // 分析メッセージ関連（要件仕様）- StreamBuilderで直接処理するため変数は不要

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null || widget.userId != null) {
      _fetchAndProcessMoodLogs();
    }
  }

  Future<void> _fetchAndProcessMoodLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _chartSpots = [];
      _bottomTitles = [];
      _spotDates = [];
    });

    try {
      final targetUserId = widget.userId ?? _currentUser?.uid;
      if (targetUserId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final stream = _firestoreService.getAiDiaryLogsStream(targetUserId);
      // Listen to the first emission for initial load, then cancel or manage updates carefully
      // For simplicity, we take all logs. In a real app, pagination or date range filtering in Firestore query would be better.
      final logs = await stream.first;
      if (!mounted) return;

      _allMoodLogs = logs;
      _allMoodLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // 古い順にソート
      _processChartData();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('気分ログの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  void _processChartData() {
    if (_allMoodLogs.isEmpty) {
      setState(() {
        _chartSpots = [];
        _bottomTitles = [];
        _spotDates = [];
      });
      return;
    }

    Map<DateTime, List<double>> scoresByDate = {}; // Key: Date (normalized), Value: List of scores
    final now = DateTime.now();
    DateTime? earliestDate;

    if (_selectedPeriod == '日別') {
      final startDate = now.subtract(Duration(days: _dailyLimit - 1));
      earliestDate = DateTime(startDate.year, startDate.month, startDate.day);
      final relevantLogs = _allMoodLogs.where((log) {
        final logDate = log.timestamp.toDate();
        return !logDate.isBefore(earliestDate!) &&
               !logDate.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59));
      });
      
      scoresByDate = groupBy(relevantLogs, (AiDiaryLog log) {
        final d = log.timestamp.toDate();
        return DateTime(d.year, d.month, d.day);
      }).map((date, logs) => 
        MapEntry(date, logs.map((l) => l.overallMoodScore ?? l.selfReportedMoodScore.toDouble()).toList())
      );

    } else if (_selectedPeriod == '週別') {
      final startDate = now.subtract(Duration(days: now.weekday -1 + (_weeklyLimit -1) * 7)); // Start of current week - N weeks
       final relevantLogs = _allMoodLogs.where((log) {
        final logDate = log.timestamp.toDate();
        return !logDate.isBefore(DateTime(startDate.year, startDate.month, startDate.day));
      });

      scoresByDate = groupBy(relevantLogs, (AiDiaryLog log) {
        final d = log.timestamp.toDate();
        return d.subtract(Duration(days: d.weekday - 1)); // Monday of the week
      }).map((date, logs) => 
        MapEntry(DateTime(date.year, date.month, date.day), logs.map((l) => l.overallMoodScore ?? l.selfReportedMoodScore.toDouble()).toList())
      );

    } else if (_selectedPeriod == '月別') {
      final startDate = DateTime(now.year, now.month - (_monthlyLimit - 1), 1);
      final relevantLogs = _allMoodLogs.where((log) {
        final logDate = log.timestamp.toDate();
        return !logDate.isBefore(startDate);
      });

      scoresByDate = groupBy(relevantLogs, (AiDiaryLog log) {
        final d = log.timestamp.toDate();
        return DateTime(d.year, d.month, 1); // First day of the month
      }).map((date, logs) => 
        MapEntry(date, logs.map((l) => l.overallMoodScore ?? l.selfReportedMoodScore.toDouble()).toList())
      );
    }

    List<MapEntry<DateTime, List<double>>> sortedEntries = scoresByDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    int limit = _dailyLimit;
    if(_selectedPeriod == '週別') limit = _weeklyLimit;
    if(_selectedPeriod == '月別') limit = _monthlyLimit;

    if (sortedEntries.length > limit) {
      sortedEntries = sortedEntries.sublist(sortedEntries.length - limit);
    }

    List<FlSpot> tempSpots = [];
    List<String> tempTitles = [];
    List<DateTime> tempSpotDates = [];

    if (_selectedPeriod == '日別' && sortedEntries.isNotEmpty) {
      // 日別の場合は実際の日数の間隔を反映
      final firstDate = sortedEntries.first.key;
      
      for (final entry in sortedEntries) {
        final daysDiff = entry.key.difference(firstDate).inDays.toDouble();
        final avgScore = entry.value.isNotEmpty ? entry.value.reduce((a, b) => a + b) / entry.value.length : 0.0;
        tempSpots.add(FlSpot(daysDiff, double.parse(avgScore.toStringAsFixed(1))));
        tempSpotDates.add(entry.key);
        tempTitles.add(DateFormat('MM/dd').format(entry.key));
      }
    } else {
      // 週別・月別の場合は従来通りインデックスを使用
      for (int i = 0; i < sortedEntries.length; i++) {
        final entry = sortedEntries[i];
        final avgScore = entry.value.isNotEmpty ? entry.value.reduce((a, b) => a + b) / entry.value.length : 0.0;
        tempSpots.add(FlSpot(i.toDouble(), double.parse(avgScore.toStringAsFixed(1))));
        tempSpotDates.add(entry.key);
        if (_selectedPeriod == '週別') {
          tempTitles.add(DateFormat('MM/dd').format(entry.key)); // Start of week
        } else { // 月別
          tempTitles.add(DateFormat('yy/MM').format(entry.key));
        }
      }
    }
    
    setState(() {
      _chartSpots = tempSpots;
      _bottomTitles = tempTitles;
      _spotDates = tempSpotDates;
    });
  }

  SideTitles get _bottomAxisTitles {
    return SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: _selectedPeriod == '日別' ? null : 1, // 日別の場合は自動計算
      getTitlesWidget: (value, meta) {
        if (_selectedPeriod == '日別') {
          // 日別の場合、X座標から対応する日付を找す
          for (int i = 0; i < _chartSpots.length; i++) {
            if (_chartSpots[i].x == value && i < _bottomTitles.length) {
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 4,
                child: Text(_bottomTitles[i], style: const TextStyle(fontSize: 10)),
              );
            }
          }
          return const SizedBox.shrink();
        } else {
          // 週別・月別の場合は従来通り
          final index = value.toInt();
          if (index >= 0 && index < _bottomTitles.length) {
            bool showTitle = true;
            if (_bottomTitles.length > 7) {
               if (_selectedPeriod == '週別' && index % 2 != 0 && index != _bottomTitles.length -1 && index != 0) showTitle = false;
               if (_selectedPeriod == '月別' && index % 2 != 0 && index != _bottomTitles.length -1 && index != 0) showTitle = false;
            }
            if(index == 0 || index == _bottomTitles.length -1) showTitle = true;

            if (!showTitle) return const SizedBox.shrink();
            
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Text(_bottomTitles[index], style: const TextStyle(fontSize: 10)),
            );
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Find first log for the date represented by the spot for drilldown
  AiDiaryLog? getFirstLogForSpotDate(DateTime spotDate) {
    return _allMoodLogs.firstWhereOrNull((log) {
        final logDay = log.timestamp.toDate();
        if (_selectedPeriod == '日別') {
            return logDay.year == spotDate.year && logDay.month == spotDate.month && logDay.day == spotDate.day;
        }
        if (_selectedPeriod == '週別') {
            final weekStart = spotDate;
            final weekEnd = spotDate.add(const Duration(days: 6));
            return !logDay.isBefore(weekStart) && !logDay.isAfter(weekEnd.add(const Duration(days:1, microseconds: -1)));
        }
        if (_selectedPeriod == '月別') {
            return logDay.year == spotDate.year && logDay.month == spotDate.month;
        }
        return false;
    });
  }
  
  String _getDateRangeText() {
    if (_spotDates.isEmpty) return '';
    final firstDate = _spotDates.first;
    final lastDate = _spotDates.last;
    final dateFormat = DateFormat('yyyy/MM/dd');
    return '${dateFormat.format(firstDate)} - ${dateFormat.format(lastDate)}';
  }
  
  Color _getScoreColor(double score) {
    if (score >= 4.5) return Colors.green;
    if (score >= 3.5) return Colors.lightGreen;
    if (score >= 2.5) return Colors.grey;
    if (score >= 1.5) return Colors.orange;
    return Colors.red;
  }
  
  IconData _getScoreIcon(double score) {
    if (score >= 4.5) return Icons.sentiment_very_satisfied;
    if (score >= 3.5) return Icons.sentiment_satisfied;
    if (score >= 2.5) return Icons.sentiment_neutral;
    if (score >= 1.5) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }

  // 要件仕様：Firestoreから分析メッセージをStreamBuilderで監視する関数
  Stream<DocumentSnapshot> _getAnalysisMessagesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    // 要件仕様のパス: users/{userId}/analysisMessages/messages
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('analysisMessages')
        .doc('messages')
        .snapshots();
  }

  // 要件仕様：期間に応じた分析メッセージを取得（DocumentSnapshotから処理）
  String getAnalysisMessage(DocumentSnapshot? snapshot, {bool isUpdating = false}) {
    if (isUpdating) {
      return 'ココロンが分析中だワン...🐕';
    }
    
    if (snapshot == null || !snapshot.exists || snapshot.data() == null) {
      return '日記を書いて、あなたのことをもっと教えてね！';
    }
    
    final data = snapshot.data() as Map<String, dynamic>;
    
    // 選択された期間に応じてメッセージを返す
    switch (_selectedPeriod) {
      case '週別':
        return data['weeklyMessage'] as String? ?? '日記を書いて、あなたのことをもっと教えてね！';
      case '月別':
        return data['monthlyMessage'] as String? ?? '日記を書いて、あなたのことをもっと教えてね！';
      case '日別':
      default:
        return data['dailyMessage'] as String? ?? '日記を書いて、あなたのことをもっと教えてね！';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('気分グラフ'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (String value) {
              if (_selectedPeriod != value) {
                setState(() {
                  _selectedPeriod = value;
                  _fetchAndProcessMoodLogs();
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: '日別', child: Text('日別 (直近30日)')),
              const PopupMenuItem<String>(value: '週別', child: Text('週別 (直近12週)')),
              const PopupMenuItem<String>(value: '月別', child: Text('月別 (直近12ヶ月)')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: Column(
        children: [
          // 分析メッセージ部分（自分のグラフを表示する場合のみ）
          if (!widget.isViewOnly && widget.userId == null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: StreamBuilder<DocumentSnapshot>(
                stream: _getAnalysisMessagesStream(),
                builder: (context, snapshot) {
                  // エラーハンドリング
                  if (snapshot.hasError) {
                    return Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'メッセージの読み込みでエラーが発生しました😢',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // 接続状態のチェック
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ココロンが準備中だワン...🐕',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // isUpdatingフィールドをチェック
                  final data = snapshot.data?.exists == true ? snapshot.data!.data() as Map<String, dynamic>? : null;
                  final isUpdating = data?['isUpdating'] as bool? ?? false;

                  // コールバックでメッセージ変更を通知
                  if (widget.onForecastMessageChanged != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      widget.onForecastMessageChanged!(getAnalysisMessage(snapshot.data, isUpdating: isUpdating));
                    });
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isUpdating 
                              ? Colors.orange.withValues(alpha: 0.2)
                              : AppTheme.primaryColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: isUpdating
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
                                ),
                              )
                            : Icon(
                                Icons.pets,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          getAnalysisMessage(snapshot.data, isUpdating: isUpdating),
                          style: TextStyle(
                            fontSize: 14,
                            color: isUpdating 
                                ? Colors.orange[700]
                                : AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          
          // グラフ部分
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _chartSpots.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.insert_chart_outlined,
                                size: 64,
                                color: AppTheme.primaryColor.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'データがありません',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$_selectedPeriodの表示できる気分ログがありません',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.edit_note),
                              label: const Text('日記を書く'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: BorderSide(color: AppTheme.primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // タイトルと期間表示
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.show_chart,
                                    color: AppTheme.primaryColor,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$_selectedPeriodの平均気分スコア',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _getDateRangeText(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 現在の平均スコアを表示
                                  if (_chartSpots.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getScoreColor(_chartSpots.last.y).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getScoreIcon(_chartSpots.last.y),
                                            size: 20,
                                            color: _getScoreColor(_chartSpots.last.y),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _chartSpots.last.y.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _getScoreColor(_chartSpots.last.y),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: true,
                                    horizontalInterval: 1,
                                    verticalInterval: 1,
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color: AppTheme.textTertiaryColor.withValues(alpha: 0.2),
                                        strokeWidth: 1,
                                      );
                                    },
                                    getDrawingVerticalLine: (value) {
                                      return FlLine(
                                        color: AppTheme.textTertiaryColor.withValues(alpha: 0.1),
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          final icons = {
                                            1: Icons.sentiment_very_dissatisfied,
                                            2: Icons.sentiment_dissatisfied,
                                            3: Icons.sentiment_neutral,
                                            4: Icons.sentiment_satisfied,
                                            5: Icons.sentiment_very_satisfied,
                                          };
                                          final colors = {
                                            1: Colors.red,
                                            2: Colors.orange,
                                            3: Colors.grey,
                                            4: Colors.lightGreen,
                                            5: Colors.green,
                                          };
                                          if (icons.containsKey(value.toInt())) {
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Icon(
                                                icons[value.toInt()],
                                                size: 20,
                                                color: colors[value.toInt()],
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(sideTitles: _bottomAxisTitles),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border.all(
                                      color: AppTheme.textTertiaryColor.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  minX: _chartSpots.isNotEmpty ? _chartSpots.first.x : 0,
                                  maxX: _chartSpots.isNotEmpty ? _chartSpots.last.x : 0,
                                  minY: 1,
                                  maxY: 5,
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _chartSpots,
                                      isCurved: false,
                                      barWidth: 4,
                                      isStrokeCapRound: true,
                                      color: AppTheme.primaryColor,
                                      dotData: FlDotData(
                                        show: true,
                                        getDotPainter: (spot, percent, barData, index) {
                                          return FlDotCirclePainter(
                                            radius: 6,
                                            color: Colors.white,
                                            strokeWidth: 3,
                                            strokeColor: AppTheme.primaryColor,
                                          );
                                        },
                                      ),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            AppTheme.primaryColor.withValues(alpha: 0.3),
                                            AppTheme.primaryColor.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  lineTouchData: LineTouchData(
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipColor: (spot) => AppTheme.primaryColor.withValues(alpha: 0.9),
                                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                                        return touchedBarSpots.map((barSpot) {
                                          final flSpot = barSpot;
                                          String title = "";
                                          if (flSpot.x.toInt() >= 0 && flSpot.x.toInt() < _bottomTitles.length) {
                                            title = _bottomTitles[flSpot.x.toInt()] + "\n";
                                          }
                                          return LineTooltipItem(
                                            title + '平均スコア: ${flSpot.y.toStringAsFixed(1)}',
                                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          );
                                        }).toList();
                                      }
                                    ),
                                    handleBuiltInTouches: true,
                                    getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                                      return spotIndexes.map((index) {
                                        return TouchedSpotIndicatorData(
                                          FlLine(color: AppTheme.secondaryColor.withValues(alpha: 0.5), strokeWidth: 4),
                                          FlDotData(
                                            getDotPainter: (spot, percent, barData, index) => 
                                              FlDotCirclePainter(radius: 8, color: AppTheme.secondaryColor, strokeColor: Colors.white, strokeWidth: 2),
                                          ),
                                        );
                                      }).toList();
                                    },
                                    touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                                      if (!event.isInterestedForInteractions || touchResponse == null || touchResponse.lineBarSpots == null) {
                                        return;
                                      }
                                      final value = touchResponse.lineBarSpots![0];
                                      if (event is FlTapUpEvent) {
                                         final int spotIndex = value.spotIndex;
                                         if(spotIndex >= 0 && spotIndex < _spotDates.length) {
                                           final DateTime spotDate = _spotDates[spotIndex];
                                           final AiDiaryLog? logToView = getFirstLogForSpotDate(spotDate);
                                           if (logToView != null) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => AiDiaryLogDetailScreen(log: logToView),
                                                ),
                                              );
                                           } else {
                                             ScaffoldMessenger.of(context).showSnackBar(
                                               SnackBar(content: Text('該当期間のログは見つかりませんでした (${DateFormat("yyyy/MM/dd").format(spotDate)})。'))
                                             );
                                           }
                                         }
                                      }
                                    },
                                  ),
                                ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // タップで詳細を見るヒント
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'グラフの点をタップすると詳細が見れます',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
