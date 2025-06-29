import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/models/supporter_link_model.dart';
import 'package:mental_wellness_app/models/user_model.dart';
import 'package:mental_wellness_app/models/ai_diary_log_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/screens/empathetic_chat_screen.dart';
import 'package:mental_wellness_app/screens/supporter_invitations_screen.dart';
import 'package:mental_wellness_app/screens/supporter_management_screen.dart';
import 'package:mental_wellness_app/features/partner_specific/ai_comm_soudan/presentation/screens/partner_ai_chat_screen.dart';
import 'package:mental_wellness_app/features/user_specific/mood_graph/presentation/screens/mood_graph_screen.dart';
import 'package:mental_wellness_app/features/user_specific/mental_hints/screens/mental_hints_screen.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';

class CommunicationHubScreenV3 extends StatefulWidget {
  const CommunicationHubScreenV3({super.key});

  @override
  State<CommunicationHubScreenV3> createState() => _CommunicationHubScreenV3State();
}

class _CommunicationHubScreenV3State extends State<CommunicationHubScreenV3> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('ログインしていません。')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('つながり'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'サポーター管理',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SupporterManagementScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ココロンとのおしゃべりセクション
            const Text(
              'ココロンとおしゃべり',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context: context,
              icon: Icons.pets,
              title: 'ココロンとおしゃべり',
              description: '相棒のワンちゃんがいつでも寄り添います',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmpatheticChatScreen(),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // つながっている人セクション
            const Text(
              'つながっている人',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 招待通知
            StreamBuilder<List<SupporterLink>>(
              stream: _firestoreService.getPendingInvitesStream(currentUser.uid),
              builder: (context, inviteSnapshot) {
                final pendingInvites = inviteSnapshot.data ?? [];
                
                if (pendingInvites.isNotEmpty) {
                  return Column(
                    children: [
                      _buildFeatureCard(
                        context: context,
                        icon: Icons.mail,
                        title: '新しい招待があります',
                        description: '${pendingInvites.length}件の招待を確認してください',
                        iconColor: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SupporterInvitationsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
            // つながりリスト
            StreamBuilder<List<SupporterLink>>(
              stream: _firestoreService.getSupporterLinksStream(currentUser.uid),
              builder: (context, supporterSnapshot) {
                final supportingLinks = supporterSnapshot.data ?? [];
                
                return StreamBuilder<List<SupporterLink>>(
                  stream: _firestoreService.getUserSupportersStream(currentUser.uid),
                  builder: (context, userSnapshot) {
                    final supportedByLinks = userSnapshot.data ?? [];
                    final acceptedSupports = supportedByLinks
                        .where((s) => s.status == SupporterLinkStatus.accepted)
                        .toList();
                    
                    // 統合リストの作成
                    final allConnections = <String, _ConnectionInfo>{};
                    
                    // 自分がサポートしている人を追加
                    for (var link in supportingLinks) {
                      allConnections[link.userId] = _ConnectionInfo(
                        userId: link.userId,
                        supporterLink: link,
                        isSupporting: true,
                        isSupportedBy: false,
                      );
                    }
                    
                    // 自分をサポートしている人を追加/更新
                    for (var link in acceptedSupports) {
                      if (allConnections.containsKey(link.supporterId)) {
                        allConnections[link.supporterId]!.isSupportedBy = true;
                        allConnections[link.supporterId]!.userLink = link;
                      } else {
                        allConnections[link.supporterId] = _ConnectionInfo(
                          userId: link.supporterId,
                          userLink: link,
                          isSupporting: false,
                          isSupportedBy: true,
                        );
                      }
                    }
                    
                    if (allConnections.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: AppTheme.textTertiaryColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'まだ誰ともつながっていません',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SupporterManagementScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.person_add),
                                label: const Text('サポーターを追加'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return Column(
                      children: allConnections.values
                          .map((info) => _buildConnectionCard(info))
                          .toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? AppTheme.primaryColor).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppTheme.primaryColor,
                size: 24,
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textTertiaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(_ConnectionInfo info) {
    return FutureBuilder<UserProfile?>(
      future: _firestoreService.getUserProfile(info.userId),
      builder: (context, snapshot) {
        final userProfile = snapshot.data;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showConnectionOptions(info),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userProfile?.displayName ?? userProfile?.email ?? '不明なユーザー',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (info.isSupporting && info.isSupportedBy) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '相互サポート',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else if (info.isSupporting) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'サポート中',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ] else if (info.isSupportedBy) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'サポートされています',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PartnerAiChatScreen(
                            supportedUserId: info.userId,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showConnectionOptions(_ConnectionInfo info) {
    final link = info.supporterLink ?? info.userLink;
    if (link == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info.isSupporting) ...[
              ListTile(
                leading: const Icon(Icons.show_chart),
                title: const Text('気分グラフを見る'),
                enabled: link.permissions.canViewMoodGraph,
                onTap: link.permissions.canViewMoodGraph
                    ? () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MoodGraphScreen(
                              userId: link.userId,
                              isViewOnly: true,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('心のヒントを見る'),
                enabled: link.permissions.canViewMentalHints,
                onTap: link.permissions.canViewMentalHints
                    ? () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MentalHintsScreen(
                              userId: link.userId,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _viewMoodScore(String userId) async {
    final diaryLogs = await _firestoreService.getAiDiaryLogsStream(userId).first;
    if (diaryLogs.isNotEmpty && mounted) {
      final latestLog = diaryLogs.first;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('最新の気分スコア'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getMoodIcon(latestLog.selfReportedMoodScore),
                size: 60,
                color: _getMoodColor(latestLog.selfReportedMoodScore),
              ),
              const SizedBox(height: 16),
              Text(
                '${latestLog.selfReportedMoodScore}/5',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getMoodDescription(latestLog.selfReportedMoodScore),
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('気分スコアのデータがありません')),
      );
    }
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
}

// 連携情報を管理するクラス
class _ConnectionInfo {
  final String userId;
  SupporterLink? supporterLink; // 自分がサポーター時のリンク
  SupporterLink? userLink; // 自分が当事者時のリンク
  bool isSupporting; // 自分がサポートしている
  bool isSupportedBy; // 自分がサポートされている
  
  _ConnectionInfo({
    required this.userId,
    this.supporterLink,
    this.userLink,
    required this.isSupporting,
    required this.isSupportedBy,
  });
}