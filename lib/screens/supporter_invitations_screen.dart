import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';
import 'package:mental_wellness_app/models/supporter_link_model.dart';
import 'package:mental_wellness_app/models/user_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:intl/intl.dart';

class SupporterInvitationsScreen extends StatefulWidget {
  const SupporterInvitationsScreen({super.key});

  @override
  State<SupporterInvitationsScreen> createState() => _SupporterInvitationsScreenState();
}

class _SupporterInvitationsScreenState extends State<SupporterInvitationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _acceptInvite(String linkId) async {
    try {
      await _firestoreService.acceptSupporterInvite(linkId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('招待を承認しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _declineInvite(String linkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('招待を拒否'),
        content: const Text('この招待を拒否しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '拒否する',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.declineSupporterInvite(linkId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('招待を拒否しました')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<UserProfile?> _getUserProfile(String userId) async {
    try {
      return await _firestoreService.getUserProfile(userId);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('ログインが必要です')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('サポーター招待'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: StreamBuilder<List<SupporterLink>>(
        stream: _firestoreService.getPendingInvitesStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('エラー: ${snapshot.error}'),
            );
          }

          final invitations = snapshot.data ?? [];

          if (invitations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 80,
                    color: AppTheme.textTertiaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '新しい招待はありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final invitation = invitations[index];
              return FutureBuilder<UserProfile?>(
                future: _getUserProfile(invitation.userId),
                builder: (context, userSnapshot) {
                  return _InvitationCard(
                    invitation: invitation,
                    inviterProfile: userSnapshot.data,
                    onAccept: () => _acceptInvite(invitation.id),
                    onDecline: () => _declineInvite(invitation.id),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final SupporterLink invitation;
  final UserProfile? inviterProfile;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationCard({
    required this.invitation,
    this.inviterProfile,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm', 'ja_JP');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        inviterProfile?.displayName ?? inviterProfile?.email ?? '不明なユーザー',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (inviterProfile?.displayName != null && inviterProfile?.email != null)
                        Text(
                          inviterProfile!.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'あなたをサポーターとして招待しています',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'この招待を承認すると、以下の情報にアクセスできるようになります：',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FeatureItem(
                    icon: Icons.wb_sunny_outlined,
                    text: 'ココロの天気予報（抽象化された心の状態）',
                    enabled: invitation.permissions.canViewMentalWeather,
                  ),
                  _FeatureItem(
                    icon: Icons.mood,
                    text: '気分スコア（1-5の数値）',
                    enabled: invitation.permissions.canViewMoodScore,
                  ),
                  _FeatureItem(
                    icon: Icons.show_chart,
                    text: '気分グラフ（推移の可視化）',
                    enabled: invitation.permissions.canViewMoodGraph,
                  ),
                  _FeatureItem(
                    icon: Icons.chat_bubble_outline,
                    text: 'AIチャット相談（サポート方法のアドバイス）',
                    enabled: invitation.permissions.canUseAIChat,
                  ),
                  _FeatureItem(
                    icon: Icons.notifications_outlined,
                    text: '状態変化の通知',
                    enabled: invitation.permissions.canReceiveNotifications,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppTheme.textTertiaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '招待日時: ${dateFormat.format(invitation.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiaryColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(color: AppTheme.errorColor),
                    ),
                    child: const Text('拒否'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('承認'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool enabled;

  const _FeatureItem({
    required this.icon,
    required this.text,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.primaryColor : AppTheme.textTertiaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: enabled ? AppTheme.textPrimaryColor : AppTheme.textTertiaryColor,
                decoration: enabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          if (enabled)
            Icon(
              Icons.check_circle,
              size: 16,
              color: color,
            ),
        ],
      ),
    );
  }
}