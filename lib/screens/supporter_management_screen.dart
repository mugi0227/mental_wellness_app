import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';
import 'package:mental_wellness_app/models/supporter_link_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:intl/intl.dart';

class SupporterManagementScreen extends StatefulWidget {
  const SupporterManagementScreen({super.key});

  @override
  State<SupporterManagementScreen> createState() => _SupporterManagementScreenState();
}

class _SupporterManagementScreenState extends State<SupporterManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // デバッグ: 自分のプロファイルを確認
      final myProfile = await _firestoreService.getUserProfile(user.uid);
      print('My profile email: ${myProfile?.email}');
      
      // デバッグ: 招待先ユーザーを検索
      final targetEmail = _emailController.text.trim();
      print('Searching for user with email: $targetEmail');
      
      // デバッグ: 全ユーザーを確認（一時的）
      try {
        final allUsersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .get();
        print('Total users in Firestore: ${allUsersSnapshot.docs.length}');
        for (var doc in allUsersSnapshot.docs) {
          final data = doc.data();
          print('User ${doc.id}: email=${data['email']}, displayName=${data['displayName']}');
        }
      } catch (e) {
        print('Error listing all users: $e');
      }
      
      await _firestoreService.sendSupporterInvite(
        userId: user.uid,
        supporterEmail: targetEmail,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('招待を送信しました')),
        );
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeSupporterLink(String linkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サポーター連携を解除'),
        content: const Text('このサポーターとの連携を解除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '解除する',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.removeSupporterLink(linkId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('連携を解除しました')),
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

  Future<void> _showPermissionSettings(SupporterLink link) async {
    await showDialog(
      context: context,
      builder: (context) => _PermissionSettingsDialog(
        link: link,
        onSave: (permissions) async {
          try {
            await _firestoreService.updateSupporterPermissions(
              link.id,
              permissions,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('権限を更新しました')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('エラー: ${e.toString()}')),
              );
            }
          }
        },
      ),
    );
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
        title: const Text('サポーター管理'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 新規サポーター招待セクション
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '新しいサポーターを招待',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'メールアドレス',
                      hintText: 'supporter@example.com',
                      prefixIcon: const Icon(Icons.email),
                      suffixIcon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _sendInvite,
                            ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'メールアドレスを入力してください';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return '有効なメールアドレスを入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '※ サポーターになる方は事前にアプリへの登録が必要です',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // サポーターリスト
          Expanded(
            child: StreamBuilder<List<SupporterLink>>(
              stream: _firestoreService.getUserSupportersStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('エラー: ${snapshot.error}'),
                  );
                }

                final supporters = snapshot.data ?? [];

                if (supporters.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: AppTheme.textTertiaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'まだサポーターがいません',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '上のフォームから招待を送信しましょう',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textTertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: supporters.length,
                  itemBuilder: (context, index) {
                    final supporter = supporters[index];
                    return _SupporterCard(
                      supporter: supporter,
                      onRemove: () => _removeSupporterLink(supporter.id),
                      onEditPermissions: () => _showPermissionSettings(supporter),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SupporterCard extends StatelessWidget {
  final SupporterLink supporter;
  final VoidCallback onRemove;
  final VoidCallback onEditPermissions;

  const _SupporterCard({
    required this.supporter,
    required this.onRemove,
    required this.onEditPermissions,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(supporter.status);
    final statusText = _getStatusText(supporter.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.person,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supporter.supporterDisplayName ?? supporter.supporterEmail,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (supporter.supporterDisplayName != null)
                        Text(
                          supporter.supporterEmail,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 権限情報
            if (supporter.status == SupporterLinkStatus.accepted) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (supporter.permissions.canViewMentalWeather)
                    _PermissionChip(
                      icon: Icons.wb_sunny_outlined,
                      label: 'ココロの天気',
                    ),
                  if (supporter.permissions.canViewMoodScore)
                    _PermissionChip(
                      icon: Icons.mood,
                      label: '気分スコア',
                    ),
                  if (supporter.permissions.canViewMoodGraph)
                    _PermissionChip(
                      icon: Icons.show_chart,
                      label: '気分グラフ',
                    ),
                  if (supporter.permissions.canUseAIChat)
                    _PermissionChip(
                      icon: Icons.chat_bubble_outline,
                      label: 'AI相談',
                    ),
                  if (supporter.permissions.canReceiveNotifications)
                    _PermissionChip(
                      icon: Icons.notifications_outlined,
                      label: '通知',
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 日付情報
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppTheme.textTertiaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _getDateText(supporter),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiaryColor,
                  ),
                ),
              ],
            ),

            // アクションボタン
            if (supporter.status == SupporterLinkStatus.accepted ||
                supporter.status == SupporterLinkStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (supporter.status == SupporterLinkStatus.accepted)
                    TextButton.icon(
                      onPressed: onEditPermissions,
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('権限設定'),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.link_off, size: 16),
                    label: const Text('連携解除'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(SupporterLinkStatus status) {
    switch (status) {
      case SupporterLinkStatus.accepted:
        return Colors.green;
      case SupporterLinkStatus.pending:
        return Colors.orange;
      case SupporterLinkStatus.declined:
        return Colors.red;
      case SupporterLinkStatus.removed:
        return Colors.grey;
    }
  }

  String _getStatusText(SupporterLinkStatus status) {
    switch (status) {
      case SupporterLinkStatus.accepted:
        return '連携中';
      case SupporterLinkStatus.pending:
        return '承認待ち';
      case SupporterLinkStatus.declined:
        return '拒否済み';
      case SupporterLinkStatus.removed:
        return '解除済み';
    }
  }

  String _getDateText(SupporterLink supporter) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ja_JP');
    switch (supporter.status) {
      case SupporterLinkStatus.accepted:
        return '連携開始: ${dateFormat.format(supporter.acceptedAt!)}';
      case SupporterLinkStatus.pending:
        return '招待送信: ${dateFormat.format(supporter.createdAt)}';
      case SupporterLinkStatus.declined:
        return '拒否日時: ${dateFormat.format(supporter.declinedAt!)}';
      case SupporterLinkStatus.removed:
        return '解除日時: ${dateFormat.format(supporter.createdAt)}';
    }
  }
}

class _PermissionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PermissionChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
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

class _PermissionSettingsDialog extends StatefulWidget {
  final SupporterLink link;
  final Function(SupporterPermissions) onSave;

  const _PermissionSettingsDialog({
    required this.link,
    required this.onSave,
  });

  @override
  State<_PermissionSettingsDialog> createState() => _PermissionSettingsDialogState();
}

class _PermissionSettingsDialogState extends State<_PermissionSettingsDialog> {
  late SupporterPermissions _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = widget.link.permissions;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('権限設定'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('ココロの天気予報'),
              subtitle: const Text('心の状態を天気で表現した情報'),
              value: _permissions.canViewMentalWeather,
              onChanged: (value) {
                setState(() {
                  _permissions = _permissions.copyWith(
                    canViewMentalWeather: value,
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('気分スコア'),
              subtitle: const Text('日々の気分スコア（1-5）を表示'),
              value: _permissions.canViewMoodScore,
              onChanged: (value) {
                setState(() {
                  _permissions = _permissions.copyWith(
                    canViewMoodScore: value,
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('気分グラフ'),
              subtitle: const Text('気分の推移をグラフで可視化'),
              value: _permissions.canViewMoodGraph,
              onChanged: (value) {
                setState(() {
                  _permissions = _permissions.copyWith(
                    canViewMoodGraph: value,
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('AI相談機能'),
              subtitle: const Text('サポーター向けAIチャット相談'),
              value: _permissions.canUseAIChat,
              onChanged: (value) {
                setState(() {
                  _permissions = _permissions.copyWith(
                    canUseAIChat: value,
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('通知受信'),
              subtitle: const Text('状態変化を通知で受け取る'),
              value: _permissions.canReceiveNotifications,
              onChanged: (value) {
                setState(() {
                  _permissions = _permissions.copyWith(
                    canReceiveNotifications: value,
                  );
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_permissions);
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}