import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mental_wellness_app/services/health_service.dart';

class HealthDataScreen extends StatefulWidget {
  const HealthDataScreen({super.key});

  @override
  State<HealthDataScreen> createState() => _HealthDataScreenState();
}

class _HealthDataScreenState extends State<HealthDataScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> _sleepData = [];
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
    
    // Web ではヘルスデータを取得しない
    if (kIsWeb) {
      setState(() {
        _errorMessage = 'ヘルスデータはWebでは利用できません';
      });
      return;
    }
    
    // モバイルでのヘルスデータ取得処理
    setState(() => _isLoading = true);
    
    try {
      // 権限チェック
      bool hasPermission = await HealthService.checkHealthPermissions();
      if (!hasPermission && !_healthAuthRequested) {
        bool granted = await HealthService.requestHealthPermissions();
        setState(() {
          _healthAuthRequested = true;
          _isHealthAuthorized = granted;
        });
        if (!granted) {
          setState(() {
            _errorMessage = 'ヘルスデータへのアクセス許可が必要です';
            _isLoading = false;
          });
          return;
        }
      } else {
        setState(() => _isHealthAuthorized = hasPermission);
      }

      if (_isHealthAuthorized) {
        await _fetchDataForSelectedDate();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'データの取得に失敗しました: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDataForSelectedDate() async {
    if (!mounted || kIsWeb) return;
    
    setState(() => _isLoading = true);
    
    try {
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      
      // HealthService の非静的メソッドを使用
      final healthService = HealthService();
      final sleepData = await healthService.getSleepDataPoints(startOfDay, endOfDay);
      final steps = await healthService.getTotalSteps(startOfDay, endOfDay);
      final activeEnergy = await healthService.getTotalActiveEnergy(startOfDay, endOfDay);
      
      if (mounted) {
        setState(() {
          _sleepData = sleepData;
          _steps = steps;
          _activeEnergy = activeEnergy;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'データの取得に失敗しました: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    if (kIsWeb) return; // Web では日付選択を無効化
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() => _selectedDate = pickedDate);
      await _fetchDataForSelectedDate();
    }
  }

  String _formatSleepDuration(List<dynamic> sleepData) {
    if (kIsWeb) {
      return 'Web では利用できません';
    }
    
    if (sleepData.isEmpty) return 'データなし';
    
    // TODO: モバイル専用の実装が必要
    return 'データなし';
  }

  String _formatSleepSegments(List<dynamic> sleepData) {
    if (kIsWeb) {
      return 'Web では詳細な睡眠データは利用できません';
    }
    
    if (sleepData.isEmpty) return '';
    
    // TODO: モバイル専用の実装が必要
    return '詳細な睡眠データはありません。';
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('yyyy年M月d日 (E)', 'ja_JP');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ヘルスデータ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: kIsWeb 
        ? _buildWebNotSupportedView()
        : _buildMobileView(dateFormat),
    );
  }

  Widget _buildWebNotSupportedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'ヘルスデータ機能',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'この機能はWebブラウザでは利用できません',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'iOSまたはAndroidアプリをご利用ください',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileView(DateFormat dateFormat) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date selector
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Icon(Icons.calendar_today),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Center(
              child: Column(
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checkAndFetchHealthData,
                    child: const Text('再試行'),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  _buildDataCard(
                    '睡眠時間',
                    _formatSleepDuration(_sleepData),
                    Icons.bedtime,
                  ),
                  const SizedBox(height: 16),
                  _buildDataCard(
                    '歩数',
                    _steps != null ? '${_steps!.toString()} 歩' : 'データなし',
                    Icons.directions_walk,
                  ),
                  const SizedBox(height: 16),
                  _buildDataCard(
                    'アクティブカロリー',
                    _activeEnergy != null ? '${_activeEnergy!.toStringAsFixed(0)} kcal' : 'データなし',
                    Icons.local_fire_department,
                  ),
                  const SizedBox(height: 16),
                  _buildSleepDetailsCard(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, size: 24, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '睡眠の詳細',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_formatSleepSegments(_sleepData)),
          ],
        ),
      ),
    );
  }
}