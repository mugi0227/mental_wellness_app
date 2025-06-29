import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';
import 'package:mental_wellness_app/services/health_service.dart';

class PermissionsSettingsScreen extends StatefulWidget {
  const PermissionsSettingsScreen({super.key});

  @override
  State<PermissionsSettingsScreen> createState() => _PermissionsSettingsScreenState();
}

class _PermissionsSettingsScreenState extends State<PermissionsSettingsScreen> {
  bool _healthPermissionGranted = false;
  bool _locationPermissionGranted = false;
  bool _notificationPermissionGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    
    final healthStatus = await HealthService.checkHealthPermissions();
    final locationStatus = await Permission.location.status;
    final notificationStatus = await Permission.notification.status;
    
    setState(() {
      _healthPermissionGranted = healthStatus;
      _locationPermissionGranted = locationStatus.isGranted;
      _notificationPermissionGranted = notificationStatus.isGranted;
      _isLoading = false;
    });
  }

  Future<void> _requestHealthPermission() async {
    final granted = await HealthService.requestHealthPermissions();
    if (granted) {
      setState(() => _healthPermissionGranted = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ヘルスデータへのアクセスが許可されました')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ヘルスデータへのアクセスが拒否されました')),
        );
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    setState(() => _locationPermissionGranted = status.isGranted);
    
    if (status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('位置情報へのアクセスが許可されました')),
      );
    } else if (status.isPermanentlyDenied && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('位置情報の許可が必要です'),
          content: const Text('天気情報を自動で取得するには、設定アプリから位置情報の使用を許可してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('設定を開く'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    setState(() => _notificationPermissionGranted = status.isGranted);
    
    if (status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知が許可されました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('アクセス許可設定'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildPermissionSection(
                  title: 'ヘルスケアデータ',
                  subtitle: '睡眠時間を自動で記録に含めます',
                  icon: Icons.favorite,
                  isGranted: _healthPermissionGranted,
                  onRequest: _requestHealthPermission,
                  explanation: '睡眠時間と気分の相関を分析し、より良い心のヒントを提供します。',
                ),
                const SizedBox(height: 16),
                _buildPermissionSection(
                  title: '位置情報',
                  subtitle: '天気情報を自動で取得します',
                  icon: Icons.location_on,
                  isGranted: _locationPermissionGranted,
                  onRequest: _requestLocationPermission,
                  explanation: '気象条件と気分の関係を分析し、天候に合わせたアドバイスを提供します。',
                ),
                const SizedBox(height: 16),
                _buildPermissionSection(
                  title: '通知',
                  subtitle: '服薬リマインダーなどをお知らせします',
                  icon: Icons.notifications,
                  isGranted: _notificationPermissionGranted,
                  onRequest: _requestNotificationPermission,
                  explanation: 'お薬の飲み忘れ防止や、定期的な振り返りをサポートします。',
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.primaryColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'これらの権限は、あなたの心の健康をより良くサポートするために使用されます。いつでも変更可能です。',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onRequest,
    required String explanation,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isGranted 
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isGranted ? AppTheme.primaryColor : Colors.grey,
                size: 24,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            trailing: isGranted
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '許可済み',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: onRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      '許可する',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              explanation,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}