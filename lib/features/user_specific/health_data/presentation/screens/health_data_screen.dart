import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:mental_wellness_app/services/health_service.dart';

class HealthDataScreen extends StatefulWidget {
  const HealthDataScreen({super.key});

  @override
  State<HealthDataScreen> createState() => _HealthDataScreenState();
}

class _HealthDataScreenState extends State<HealthDataScreen> {
  // HealthServiceは静的メソッドと非静的メソッドが混在
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  List<HealthDataPoint> _sleepData = [];
  int? _steps;
  double? _activeEnergy;
  bool _healthAuthRequested = false;
  bool _isHealthAuthorized = false;


  @override
  void initState() {
    super.initState();
    _checkAndFetchHealthData();
  }

  Future<void> _checkAndFetchHealthData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool authorized = await HealthService().requestAuthorization();
    _isHealthAuthorized = authorized;
    _healthAuthRequested = true;

    if (authorized) {
      await _fetchDataForSelectedDate();
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'ヘルスケアデータへのアクセスが許可されていません。設定アプリから権限を許可してください。';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDataForSelectedDate() async {
    if (!_isHealthAuthorized) {
      if (mounted) {
        setState(() {
          _errorMessage = 'ヘルスケアデータへのアクセス権限がありません。';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final DateTime startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      final DateTime endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

      final sleepHours = await HealthService.getSleepData(startDate, endDate);
      final steps = await HealthService().getTotalSteps(startDate, endDate);
      final energy = await HealthService().getTotalActiveEnergy(startDate, endDate);

      if (mounted) {
        setState(() {
          _sleepData = sleepHours != null ? [] : []; // 時間データなので空リストに
          _steps = steps;
          _activeEnergy = energy;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'データの取得中にエラーが発生しました: ${e.toString()}';
        });
      }
      debugPrint('Error fetching health data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)), // Allow today
      helpText: '表示する日付を選択',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _fetchDataForSelectedDate();
    }
  }

  String _formatSleepDuration(List<HealthDataPoint> sleepData) {
    if (sleepData.isEmpty) return 'データなし';
    double totalDurationMinutes = 0;
    for (var point in sleepData) {
      final value = (point.value as NumericHealthValue).numericValue.toDouble();
      if (point.type == HealthDataType.SLEEP_ASLEEP ||
          point.type == HealthDataType.SLEEP_IN_BED || // Consider in-bed time as part of total if SLEEP_ASLEEP is not available
          point.type == HealthDataType.SLEEP_SESSION) { // For watchOS, SLEEP_SESSION duration can be used
        totalDurationMinutes += value;
      }
    }
    if (totalDurationMinutes == 0) return 'データなし';
    final duration = Duration(minutes: totalDurationMinutes.toInt());
    String hours = duration.inHours.toString();
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '${hours}時間 ${minutes}分';
  }

  String _formatSleepSegments(List<HealthDataPoint> sleepData) {
    if (sleepData.isEmpty) return '';
    
    // Filter and sort sleep data points
    List<HealthDataPoint> relevantPoints = sleepData
        .where((p) => 
            p.type == HealthDataType.SLEEP_AWAKE ||
            p.type == HealthDataType.SLEEP_ASLEEP ||
            p.type == HealthDataType.SLEEP_DEEP ||
            p.type == HealthDataType.SLEEP_REM ||
            p.type == HealthDataType.SLEEP_LIGHT ||
            p.type == HealthDataType.SLEEP_IN_BED)
        .toList();
    
    relevantPoints.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    if (relevantPoints.isEmpty) return '詳細な睡眠データはありません。';

    final DateFormat timeFormat = DateFormat('HH:mm');
    List<String> segments = [];
    for (var point in relevantPoints) {
      String typeStr = '';
      switch(point.type) {
        case HealthDataType.SLEEP_ASLEEP: typeStr = '睡眠'; break;
        case HealthDataType.SLEEP_AWAKE: typeStr = '覚醒'; break;
        case HealthDataType.SLEEP_LIGHT: typeStr = '浅い睡眠'; break;
        case HealthDataType.SLEEP_DEEP: typeStr = '深い睡眠'; break;
        case HealthDataType.SLEEP_REM: typeStr = 'レム睡眠'; break;
        case HealthDataType.SLEEP_IN_BED: typeStr = 'ベッドで過ごした時間'; break;
        default: typeStr = point.typeString;
      }
      segments.add('${timeFormat.format(point.dateFrom)} - ${timeFormat.format(point.dateTo)}: $typeStr');
    }
    return segments.join('\n');
  }


  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('yyyy年M月d日 (E)', 'ja_JP');

    return Scaffold(
      appBar: AppBar(
        title: Text('ヘルスデータ (${dateFormat.format(_selectedDate)})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: '日付を選択',
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center,),
                        if (!_isHealthAuthorized && _healthAuthRequested)
                          Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('再度連携を試す'),
                              onPressed: _checkAndFetchHealthData,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDataForSelectedDate,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: <Widget>[
                      _buildHealthDataCard(
                        icon: Icons.king_bed_outlined,
                        title: '睡眠',
                        value: _formatSleepDuration(_sleepData),
                        details: _sleepData.isNotEmpty ? _formatSleepSegments(_sleepData) : null,
                        iconColor: Colors.purple.shade300,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthDataCard(
                        icon: Icons.directions_walk_outlined,
                        title: '歩数',
                        value: _steps != null ? '${NumberFormat.decimalPattern('ja').format(_steps)} 歩' : 'データなし',
                        iconColor: Colors.green.shade400,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthDataCard(
                        icon: Icons.local_fire_department_outlined,
                        title: 'アクティブエネルギー',
                        value: _activeEnergy != null ? '${NumberFormat.decimalPattern('ja').format(_activeEnergy?.round() ?? 0)} kcal' : 'データなし',
                        iconColor: Colors.orange.shade400,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHealthDataCard({
    required IconData icon,
    required String title,
    required String value,
    String? details,
    Color? iconColor,
  }) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 32.0, color: iconColor ?? Theme.of(context).primaryColor),
                const SizedBox(width: 12.0),
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12.0),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500, color: iconColor ?? Theme.of(context).primaryColor),
            ),
            if (details != null && details.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              const Divider(),
              const SizedBox(height: 8.0),
              Text(
                '詳細:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4.0),
              Text(details, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700], height: 1.5)),
            ]
          ],
        ),
      ),
    );
  }
}
