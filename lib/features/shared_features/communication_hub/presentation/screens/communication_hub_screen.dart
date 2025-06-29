import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/models/user_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/screens/empathetic_chat_screen.dart';
import 'package:mental_wellness_app/screens/communication_advice_screen.dart';
import 'package:mental_wellness_app/features/partner_specific/ai_comm_soudan/presentation/screens/partner_ai_chat_screen.dart';
import 'package:mental_wellness_app/features/partner_specific/weather_forecast_view/presentation/screens/partner_weather_view_screen.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';

class CommunicationHubScreen extends StatefulWidget {
  const CommunicationHubScreen({super.key});

  @override
  State<CommunicationHubScreen> createState() => _CommunicationHubScreenState();
}

class _CommunicationHubScreenState extends State<CommunicationHubScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.textTertiaryColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('ログインしていません。')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('コミュニケーション'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _firestoreService.userProfileStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('ユーザープロファイルが見つかりません。'));
          }

          final userProfile = snapshot.data!;
          final partnerLink = userProfile.partnerLink;
          final isLinked = partnerLink?.status == 'linked';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // AI相談セクション
                  Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EmpatheticChatScreen(),
                          ),
                        );
                      },
                      borderRadius: AppTheme.cardBorderRadius,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.infoColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.psychology_outlined,
                                color: AppTheme.infoColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'AI相談',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '気持ちや悩みを気軽にAIに相談できます。\n24時間いつでも、あなたの話に耳を傾けます。',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryColor,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  '相談を始める',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppTheme.infoColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                  color: AppTheme.infoColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // コミュニケーション支援セクション
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.people_outline,
                              color: AppTheme.primaryColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'コミュニケーション支援',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isLinked 
                              ? '連携相手との円滑なコミュニケーションをサポートします。'
                              : 'パートナーと連携すると、コミュニケーション支援機能が利用できます。',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryColor,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (isLinked) ...[
                            _buildFeatureCard(
                              context: context,
                              icon: Icons.wb_sunny_outlined,
                              title: 'パートナーのココロの天気',
                              description: '連携相手の心の状態を確認',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PartnerWeatherViewScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureCard(
                              context: context,
                              icon: Icons.explore_outlined,
                              title: 'コミュニケーションナビ',
                              description: 'シーンに応じた会話のヒント',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CommunicationAdviceScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureCard(
                              context: context,
                              icon: Icons.chat_outlined,
                              title: 'AIチャット相談',
                              description: '連携相手との関わり方を相談',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PartnerAiChatScreen(),
                                  ),
                                );
                              },
                            ),
                          ] else ...[
                            OutlinedButton.icon(
                              icon: const Icon(Icons.link),
                              label: const Text('パートナー連携設定'),
                              onPressed: () {
                                Navigator.pushNamed(context, '/partner_link');
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // 連携状況セクション
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.link,
                              color: AppTheme.warningColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '連携状況',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          if (isLinked) ...[
                            FutureBuilder<UserProfile?>(
                              future: _firestoreService.getUserProfile(partnerLink!.linkedUserUid!),
                              builder: (context, partnerSnapshot) {
                                if (partnerSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Text('連携相手の情報を取得中...');
                                }
                                if (partnerSnapshot.hasError || !partnerSnapshot.hasData) {
                                  return Text(
                                    '連携相手の情報を取得できませんでした。',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  );
                                }
                                final partnerProfile = partnerSnapshot.data!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: AppTheme.successColor.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                (partnerProfile.displayName ?? partnerProfile.email ?? 'U')[0].toUpperCase(),
                                                style: TextStyle(
                                                  color: AppTheme.successColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  partnerProfile.displayName ?? partnerProfile.email ?? '',
                                                  style: Theme.of(context).textTheme.titleMedium,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '連携中',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: AppTheme.successColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      icon: const Icon(Icons.settings),
                                      label: const Text('連携設定を確認'),
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/partner_link');
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.textTertiaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.person_add_outlined,
                                    size: 48,
                                    color: AppTheme.textTertiaryColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '現在、誰とも連携していません',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.link),
                                    label: const Text('連携を開始'),
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/partner_link');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}