import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/models/user_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/services/cloud_function_service.dart';

class PartnerWeatherViewScreen extends StatefulWidget {
  const PartnerWeatherViewScreen({super.key});

  @override
  State<PartnerWeatherViewScreen> createState() => _PartnerWeatherViewScreenState();
}

class _PartnerWeatherViewScreenState extends State<PartnerWeatherViewScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _currentForecast;
  bool _isLoading = false;
  String? _errorMessage;
  UserProfile? _partnerProfile;

  @override
  void initState() {
    super.initState();
    _loadPartnerWeatherForecast();
  }

  Future<void> _loadPartnerWeatherForecast() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userProfile = await _firestoreService.getUserProfile(currentUser.uid);
      if (userProfile?.partnerLink?.status != 'linked') {
        setState(() {
          _errorMessage = 'パートナーと連携していません。';
          _isLoading = false;
        });
        return;
      }

      final partnerId = userProfile!.partnerLink!.linkedUserUid!;
      
      // パートナーのプロファイル取得
      _partnerProfile = await _firestoreService.getUserProfile(partnerId);
      
      // パートナーの最新の天気予報を取得
      final forecast = await _cloudFunctionService.getPartnerWeatherForecast(partnerId);
      
      setState(() {
        _currentForecast = forecast;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'エラーが発生しました: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Widget _buildWeatherIcon(String forecast) {
    // 天気予報のキーワードに基づいてアイコンを決定
    if (forecast.contains('晴れ') || forecast.contains('明るい')) {
      return const Icon(Icons.wb_sunny, size: 60, color: Colors.orange);
    } else if (forecast.contains('曇り') || forecast.contains('雲')) {
      return const Icon(Icons.wb_cloudy, size: 60, color: Colors.blueGrey);
    } else if (forecast.contains('雨') || forecast.contains('嵐')) {
      return const Icon(Icons.cloudy_snowing, size: 60, color: Colors.blueAccent);
    } else if (forecast.contains('霧') || forecast.contains('もや')) {
      return const Icon(Icons.cloud, size: 60, color: Colors.grey);
    } else {
      return const Icon(Icons.wb_cloudy, size: 60, color: Colors.blueGrey);
    }
  }

  Color _getWeatherColor(String forecast) {
    if (forecast.contains('晴れ') || forecast.contains('明るい')) {
      return Colors.orange.shade100;
    } else if (forecast.contains('曇り') || forecast.contains('雲')) {
      return Colors.blueGrey.shade100;
    } else if (forecast.contains('雨') || forecast.contains('嵐')) {
      return Colors.blue.shade100;
    } else {
      return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パートナーのココロの天気'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPartnerWeatherForecast,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_partnerProfile != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 40, color: Colors.green),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _partnerProfile!.displayName ?? 'パートナー',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            '現在のココロの天気',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            if (_isLoading) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('天気予報を取得中...'),
                    ],
                  ),
                ),
              ),
            ] else if (_errorMessage != null) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPartnerWeatherForecast,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_currentForecast != null) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: _getWeatherColor(_currentForecast!),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          _buildWeatherIcon(_currentForecast!),
                          const SizedBox(height: 16),
                          Text(
                            _currentForecast!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue[600]),
                                const SizedBox(width: 8),
                                const Text(
                                  'サポートのヒント',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'この天気予報は、パートナーの気持ちの状態を表現したものです。\n\n・無理に解決策を提案せず、まずは話を聞いてみましょう\n・相手のペースを大切にしてください\n・心配なことがあれば、AIコミュニケーション相談をご活用ください',
                              style: TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat),
                        label: const Text('AIコミュニケーション相談'),
                        onPressed: () {
                          Navigator.pushNamed(context, '/partner_ai_chat');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '天気予報データがありません',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}