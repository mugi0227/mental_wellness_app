import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/cloud_function_service.dart';
import '../../../../widgets/ai_character_widget.dart';

class MentalHintsScreen extends StatefulWidget {
  final String? userId; // 表示対象のユーザーID（オプショナル）

  const MentalHintsScreen({super.key, this.userId});

  @override
  State<MentalHintsScreen> createState() => _MentalHintsScreenState();
}

class _MentalHintsScreenState extends State<MentalHintsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();
  
  Stream<DocumentSnapshot>? _hintsStream;
  String? _targetUserId;

  @override
  void initState() {
    super.initState();
    // Safely determine the target user ID.
    final String? targetId = widget.userId ?? _auth.currentUser?.uid;

    if (targetId != null) {
      _targetUserId = targetId;
      _initializeHintsStream();
    }
    // If targetId is null, _hintsStream remains null, and the build method
    // will show the 'login required' message.
  }

  void _initializeHintsStream() {
    if (_targetUserId == null) return;
    _hintsStream = _firestore
        .collection('users')
        .doc(_targetUserId!)
        .collection('mentalHints')
        .doc('current')
        .snapshots();
  }

  Future<void> _triggerHintsUpdate() async {
    if (_targetUserId == null) return;
    try {
      // Cloud Functionを呼び出して更新をトリガー
      await _cloudFunctionService.getMentalHints(userId: _targetUserId!);
    } catch (e) {
      print('Failed to trigger hints update: $e');
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'positive':
        return AppTheme.positiveColor;
      case 'warning':
        return AppTheme.warningColor;
      case 'neutral':
        return AppTheme.neutralColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('心のヒント',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _hintsStream == null
          ? Stack(
              children: [
                const Center(
                  child: Text('ログインが必要です'),
                ),
                // ココロンキャラクター（右下固定）
                Positioned(
                  bottom: 50,  
                  right: 5, // さらに微調整！
                  child: SizedBox(
                    width: 400, 
                    height: 250, 
                    child: AiCharacterWidget(
                      message: 'ログインが必要だワン！🐕',
                      showMessage: true,
                      characterName: 'ココロン',
                    ),
                  ),
                ),
              ],
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: _hintsStream,
              builder: (context, snapshot) {
                return Stack(
                  children: [
                    // メインコンテンツ
                    _buildMainContent(snapshot),
                    // ココロンキャラクター（右下固定）
                    Positioned(
                      bottom: 50,  
                      right: 5, // さらに微調整���
                      child: SizedBox(
                        width: 400, 
                        height: 250, 
                        child: AiCharacterWidget(
                          message: _getCokoronMessage(snapshot),
                          showMessage: true,
                          characterName: 'ココロン',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildMainContent(AsyncSnapshot<DocumentSnapshot> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'データの読み込みに失敗しました: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _triggerHintsUpdate,
              style: AppTheme.primaryButtonStyle,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    if (!snapshot.hasData || !snapshot.data!.exists) {
      // 初回アクセス時にCloud Functionを呼び出し
      _triggerHintsUpdate();
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ココロンが分析中だワン...🐕',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      );
    }

    final hintsData = snapshot.data!.data() as Map<String, dynamic>;
    final hints = hintsData['hints'] as List? ?? [];
    final message = hintsData['message'] as String?;
    final isUpdating = hintsData['isUpdating'] as bool? ?? false;

    // isUpdatingがtrueの場合、ローディング状態を表示
    if (isUpdating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ココロンが分析中だワン...🐕',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      );
    }

    if (hints.isEmpty && message != null) {
      return RefreshIndicator(
        onRefresh: _triggerHintsUpdate,
        color: AppTheme.primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: Center(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (hints.isEmpty) {
      return RefreshIndicator(
        onRefresh: _triggerHintsUpdate,
        color: AppTheme.primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: const Center(
                child: Text(
                  'まだヒントがありません。\n日記を記録していくと、あなたの気分パターンが見えてきます。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _triggerHintsUpdate,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(), // スクロールを確実に有効化
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // 下部にココロン用スペース確保
        itemCount: hints.length,
        itemBuilder: (context, index) {
          final hint = hints[index] as Map<String, dynamic>;
          final type = hint['type'] ?? 'neutral';
          
          return _buildModernHintCard(hint, type, index);
        },
      ),
    );
  }

  String _getCokoronMessage(AsyncSnapshot<DocumentSnapshot> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return 'データを読み込み中だワン...🐕';
    }
    
    if (snapshot.hasError) {
      return 'エラーが発生したワン😔';
    }
    
    if (!snapshot.hasData || !snapshot.data!.exists) {
      return '日記を書くとヒントが見えてくるワン！🐕';
    }
    
    final hintsData = snapshot.data!.data() as Map<String, dynamic>;
    final isUpdating = hintsData['isUpdating'] as bool? ?? false;
    final hints = hintsData['hints'] as List? ?? [];
    
    if (isUpdating) {
      return 'ココロンが分析中だワン...🐕';
    }
    
    if (hints.isEmpty) {
      return '日記を書くとヒントが見えてくるワン！🐕';
    }
    
    return '今日の心のヒントをチェックするワン！💡';
  }

  Widget _buildModernHintCard(Map<String, dynamic> hint, String type, int index) {
    final typeColor = _getTypeColor(type);
    final typeGradient = _getTypeGradient(type);
    final typeBadge = _getTypeBadge(type);
    
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)), // ずらしてアニメーション
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(20),
                shadowColor: typeColor.withValues(alpha: 0.3),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: typeGradient,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      // タップ時のフィードバック
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${hint['title'] ?? 'ヒント'}を確認しました！'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: typeColor,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ヘッダー部分
                          Row(
                            children: [
                              // アイコン
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    hint['icon'] ?? '💡',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // タイトルとバッジ
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hint['title'] ?? 'ヒント',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    typeBadge,
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // コンテンツ部分
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              hint['content'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[800],
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  LinearGradient _getTypeGradient(String type) {
    switch (type) {
      case 'positive':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade400,
            Colors.teal.shade500,
            Colors.green.shade600,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case 'warning':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade400,
            Colors.deepOrange.shade500,
            Colors.orange.shade600,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case 'neutral':
      default:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade400,
            Colors.indigo.shade500,
            Colors.blue.shade600,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
    }
  }

  Widget _getTypeBadge(String type) {
    String text;
    Color color;
    IconData icon;
    
    switch (type) {
      case 'positive':
        text = 'ポジティブ';
        color = Colors.green.shade700;
        icon = Icons.thumb_up;
        break;
      case 'warning':
        text = '注意';
        color = Colors.orange.shade700;
        icon = Icons.warning;
        break;
      case 'neutral':
      default:
        text = '中立';
        color = Colors.blue.shade700;
        icon = Icons.info;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}