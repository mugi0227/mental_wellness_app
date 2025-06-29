import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/models/supporter_link_model.dart';
import 'package:mental_wellness_app/models/user_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/screens/empathetic_chat_screen.dart';
import 'package:mental_wellness_app/screens/communication_advice_screen.dart';
import 'package:mental_wellness_app/screens/supporter_invitations_screen.dart';
import 'package:mental_wellness_app/screens/supporter_management_screen.dart';
import 'package:mental_wellness_app/features/partner_specific/ai_comm_soudan/presentation/screens/partner_ai_chat_screen.dart';
import 'package:mental_wellness_app/features/user_specific/mood_graph/presentation/screens/mood_graph_screen.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';

class CommunicationHubScreenV2 extends StatefulWidget {
  const CommunicationHubScreenV2({super.key});

  @override
  State<CommunicationHubScreenV2> createState() => _CommunicationHubScreenV2State();
}

class _CommunicationHubScreenV2State extends State<CommunicationHubScreenV2> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  Widget _buildSupporterCard(SupporterLink link) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
          child: Icon(
            Icons.person,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(link.supporterDisplayName ?? link.supporterEmail),
        subtitle: Row(
          children: [
            if (link.permissions.canViewMoodScore)
              Icon(Icons.mood, size: 16, color: AppTheme.textSecondaryColor),
            if (link.permissions.canViewMoodGraph)
              Icon(Icons.show_chart, size: 16, color: AppTheme.textSecondaryColor),
            if (link.permissions.canViewMentalWeather)
              Icon(Icons.wb_sunny_outlined, size: 16, color: AppTheme.textSecondaryColor),
            const SizedBox(width: 8),
            Text(
              '連携中',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PartnerAiChatScreen(
                  supportedUserId: link.userId,
                ),
              ),
            );
          },
        ),
        onTap: () {
          _showSupporterOptionsDialog(link);
        },
      ),
    );
  }

  void _showSupporterOptionsDialog(SupporterLink link) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mood),
              title: const Text('気分スコアを見る'),
              enabled: link.permissions.canViewMoodScore,
              onTap: link.permissions.canViewMoodScore
                  ? () {
                      Navigator.pop(context);
                      _viewMoodScore(link.userId);
                    }
                  : null,
            ),
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
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('ココロの天気予報を見る'),
              enabled: link.permissions.canViewMentalWeather,
              onTap: link.permissions.canViewMentalWeather
                  ? () {
                      Navigator.pop(context);
                      // TODO: ココロの天気予報画面へ遷移
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ココロの天気予報は開発中です')),
                      );
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('AI相談を開く'),
              enabled: link.permissions.canUseAIChat,
              onTap: link.permissions.canUseAIChat
                  ? () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PartnerAiChatScreen(
                            supportedUserId: link.userId,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewMoodScore(String userId) async {
    // 最新の気分スコアを取得して表示
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
      body: _buildUnifiedView(currentUser.uid),
    );
  }

  Widget _buildUnifiedView(String userId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI相談セクション
          const Text(
            'AI相談',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context: context,
            icon: Icons.favorite,
            title: '共感的AIチャット',
            description: '今の気持ちを優しく受け止めます',
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
          
          // 連携状況セクション
          const Text(
            'つながっている人',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // 自分がサポートしている人
          StreamBuilder<List<SupporterLink>>(
            stream: _firestoreService.getSupporterLinksStream(userId),
            builder: (context, supporterSnapshot) {
              final supportingLinks = supporterSnapshot.data ?? [];
              
              // 自分がサポーターになっている人
              return StreamBuilder<List<SupporterLink>>(
                stream: _firestoreService.getUserSupportersStream(userId),
                builder: (context, userSnapshot) {
                  final supportedByLinks = userSnapshot.data ?? [];
                  final acceptedSupports = supportedByLinks
                      .where((s) => s.status == SupporterLinkStatus.accepted)
                      .toList();
                  
                  // 招待通知
                  return StreamBuilder<List<SupporterLink>>(
                    stream: _firestoreService.getPendingInvitesStream(userId),
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
              );
            },
          ),
        ],
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
                leading: const Icon(Icons.mood),
                title: const Text('気分スコアを見る'),
                enabled: link.permissions.canViewMoodScore,
                onTap: link.permissions.canViewMoodScore
                    ? () {
                        Navigator.pop(context);
                        _viewMoodScore(link.userId);
                      }
                    : null,
              ),
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
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('ココロの天気予報を見る'),
                enabled: link.permissions.canViewMentalWeather,
                onTap: link.permissions.canViewMentalWeather
                    ? () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ココロの天気予報は開発中です')),
                        );
                      }
                    : null,
              ),
            ],
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('AI相談を開く'),
              onTap: () {
                Navigator.pop(context);
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
    );
  }

  // 古いタブメソッドを削除して_ConnectionInfoクラスを追加
  
  Widget _buildPermissionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context: context,
            icon: Icons.favorite,
            title: '共感的AIチャット',
            description: '今の気持ちを優しく受け止めます',
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
          const Text(
            'サポーター管理',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<SupporterLink>>(
            stream: _firestoreService.getUserSupportersStream(userId),
            builder: (context, snapshot) {
              final supporters = snapshot.data ?? [];
              final acceptedSupporters = supporters
                  .where((s) => s.status == SupporterLinkStatus.accepted)
                  .toList();

              if (acceptedSupporters.isEmpty) {
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
                          'サポーターがいません',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: acceptedSupporters
                    .map((supporter) => _buildSupporterCard(supporter))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupporterTab(String supporterId) {
    return StreamBuilder<List<SupporterLink>>(
      stream: _firestoreService.getSupporterLinksStream(supporterId),
      builder: (context, snapshot) {
        final links = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 招待通知
              StreamBuilder<List<SupporterLink>>(
                stream: _firestoreService.getPendingInvitesStream(supporterId),
                builder: (context, inviteSnapshot) {
                  final pendingInvites = inviteSnapshot.data ?? [];
                  if (pendingInvites.isNotEmpty) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: _buildFeatureCard(
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
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              if (links.isEmpty) ...[
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 50),
                      Icon(
                        Icons.support_agent,
                        size: 80,
                        color: AppTheme.textTertiaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'サポート中の方はいません',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '招待を受けると、ここに表示されます',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Text(
                  'サポート中の方',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...links.map((link) => _buildSupportedUserCard(link)).toList(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportedUserCard(SupporterLink link) {
    return FutureBuilder<UserProfile?>(
      future: _firestoreService.getUserProfile(link.userId),
      builder: (context, snapshot) {
        final userProfile = snapshot.data;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showSupporterOptionsDialog(link),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            Text(
                              userProfile?.email ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (link.permissions.canViewMoodScore)
                        _buildPermissionChip(Icons.mood, '気分スコア'),
                      if (link.permissions.canViewMoodGraph)
                        _buildPermissionChip(Icons.show_chart, '気分グラフ'),
                      if (link.permissions.canViewMentalWeather)
                        _buildPermissionChip(Icons.wb_sunny_outlined, 'ココロの天気'),
                      if (link.permissions.canUseAIChat)
                        _buildPermissionChip(Icons.chat_bubble_outline, 'AI相談'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}