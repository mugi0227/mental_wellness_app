import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';
import 'package:mental_wellness_app/screens/partner_link_screen.dart';
import 'package:mental_wellness_app/screens/supporter_management_screen.dart';
import 'package:mental_wellness_app/features/settings/presentation/screens/permissions_settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class OtherOptionsScreen extends StatelessWidget {
  const OtherOptionsScreen({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _showComingSoonDialog(BuildContext context, String feature) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('準備中'),
        content: Text('「$feature」は現在開発中です。\n今しばらくお待ちください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ログアウト'),
          content: const Text('本当にログアウトしますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
              child: Text(
                'ログアウト',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('メニュー'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // ユーザー情報セクション
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.person,
                    size: 35,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.email ?? 'ゲストユーザー',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'UID: ${user?.uid.substring(0, 8) ?? '---'}',
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
          const SizedBox(height: 8),
          
          // 設定セクション
          _MenuSection(
            title: '設定',
            items: [
              _MenuItem(
                icon: Icons.people,
                title: 'サポーター連携',
                subtitle: 'パートナーとつながる',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SupporterManagementScreen(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.account_circle,
                title: 'アカウント設定',
                subtitle: 'プロフィールの編集',
                onTap: () => _showComingSoonDialog(context, 'アカウント設定'),
              ),
              _MenuItem(
                icon: Icons.notifications,
                title: '通知設定',
                subtitle: 'リマインダーと通知の管理',
                onTap: () => _showComingSoonDialog(context, '通知設定'),
              ),
              _MenuItem(
                icon: Icons.security,
                title: 'プライバシー設定',
                subtitle: 'データの共有範囲を管理',
                onTap: () => _showComingSoonDialog(context, 'プライバシー設定'),
              ),
              _MenuItem(
                icon: Icons.phonelink_setup,
                title: 'アクセス許可設定',
                subtitle: 'ヘルスデータと位置情報の許可',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PermissionsSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          
          // サポートセクション
          _MenuSection(
            title: 'サポート',
            items: [
              _MenuItem(
                icon: Icons.help_outline,
                title: 'ヘルプ',
                subtitle: 'よくある質問と使い方',
                onTap: () => _showComingSoonDialog(context, 'ヘルプ'),
              ),
              _MenuItem(
                icon: Icons.feedback,
                title: 'フィードバック',
                subtitle: 'ご意見・ご要望をお送りください',
                onTap: () => _launchURL('mailto:support@mentalwellness.app'),
              ),
              _MenuItem(
                icon: Icons.policy,
                title: 'プライバシーポリシー',
                subtitle: '個人情報の取り扱いについて',
                onTap: () => _showComingSoonDialog(context, 'プライバシーポリシー'),
              ),
              _MenuItem(
                icon: Icons.description,
                title: '利用規約',
                subtitle: 'サービスのご利用規約',
                onTap: () => _showComingSoonDialog(context, '利用規約'),
              ),
            ],
          ),
          
          // アプリ情報セクション
          _MenuSection(
            title: 'アプリ情報',
            items: [
              _MenuItem(
                icon: Icons.info_outline,
                title: 'バージョン情報',
                subtitle: 'v1.0.0',
                onTap: () {},
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // ログアウトボタン
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _handleSignOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: BorderSide(color: AppTheme.errorColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.textTertiaryColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 24,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textTertiaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
