import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/cloud_function_service.dart';

class MentalHintsScreen extends StatefulWidget {
  const MentalHintsScreen({super.key});

  @override
  State<MentalHintsScreen> createState() => _MentalHintsScreenState();
}

class _MentalHintsScreenState extends State<MentalHintsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();
  
  Stream<DocumentSnapshot>? _hintsStream;

  @override
  void initState() {
    super.initState();
    _initializeHintsStream();
  }

  void _initializeHintsStream() {
    final user = _auth.currentUser;
    if (user != null) {
      _hintsStream = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('mentalHints')
          .doc('current')
          .snapshots();
    }
  }

  Future<void> _triggerHintsUpdate() async {
    try {
      // Cloud Functionを呼び出して更新をトリガー（初回のみ）
      await _cloudFunctionService.getMentalHints();
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
        title: const Text('心のヒント'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _hintsStream == null
          ? const Center(
              child: Text('ログインが必要です'),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: _hintsStream,
              builder: (context, snapshot) {
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
                  return Center(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }

                if (hints.isEmpty) {
                  return const Center(
                    child: Text(
                      'まだヒントがありません。\n日記を記録していくと、あなたの気分パターンが見えてきます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _triggerHintsUpdate,
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: hints.length,
                    itemBuilder: (context, index) {
                      final hint = hints[index] as Map<String, dynamic>;
                      final typeColor = _getTypeColor(hint['type'] ?? 'neutral');
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    hint['icon'] ?? '💡',
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      hint['title'] ?? 'ヒント',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: typeColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  hint['content'] ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: typeColor.withValues(alpha: 0.9),
                                    height: 1.5,
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
              },
            ),
    );
  }
}