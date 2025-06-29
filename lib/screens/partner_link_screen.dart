import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/models/user_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/services/health_service.dart'; // HealthServiceをインポート
import 'package:mental_wellness_app/screens/communication_advice_screen.dart'; // CommunicationAdviceScreenをインポート
import 'package:mental_wellness_app/features/partner_specific/ai_comm_soudan/presentation/screens/partner_ai_chat_screen.dart'; // AIチャット相談画面

class PartnerLinkScreen extends StatefulWidget {
  const PartnerLinkScreen({super.key});

  @override
  State<PartnerLinkScreen> createState() => _PartnerLinkScreenState();
}

class _PartnerLinkScreenState extends State<PartnerLinkScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // HealthServiceは静的メソッドを使用するためインスタンス不要
  String? _healthAuthStatusMessage; // ヘルスケア連携ステータス表示用メッセージ
  bool _isHealthAuthorized = false; // ヘルスケア連携が許可されているか
  bool _isRequestingHealthAuth = false; // ヘルスケア連携リクエスト中か
  final _partnerEmailController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _partnerEmailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    if (_partnerEmailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'パートナーのメールアドレスを入力してください。';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('ユーザーがログインしていません。');
      }
      await _firestoreService.sendPartnerInvite(currentUser.uid, _partnerEmailController.text);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('招待を送信しました。')),
      );
      _partnerEmailController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvite(String inviterUid) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('ユーザーがログインしていません。');
      await _firestoreService.acceptPartnerInvite(currentUser.uid, inviterUid);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('招待を承認しました。')),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _declineInvite(String inviterUid) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('ユーザーがログインしていません。');
      await _firestoreService.declinePartnerInvite(currentUser.uid, inviterUid);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('招待を拒否しました。')),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unlinkPartner(String partnerUid) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('ユーザーがログインしていません。');
      await _firestoreService.unlinkPartner(currentUser.uid, partnerUid);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('連携を解除しました。')),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ヘルスケアデータの権限をリクエストするメソッド
  Future<void> _requestHealthAuth() async {
    setState(() {
      _isRequestingHealthAuth = true;
      _healthAuthStatusMessage = '権限をリクエスト中...';
    });
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      bool granted = await HealthService().requestAuthorization();
      setState(() {
        _isHealthAuthorized = granted;
        _healthAuthStatusMessage = granted 
            ? 'ヘルスケアデータへのアクセスが許可されました。' 
            : 'ヘルスケアデータへのアクセスが拒否されました。設定アプリから権限を許可してください。';
      });

      // 権限取得後、テスト的にデータを取得して表示
      if (granted && mounted) {
        DateTime now = DateTime.now();
        DateTime yesterday = now.subtract(const Duration(days: 1));
        var sleepHours = await HealthService.getSleepData(yesterday, now);
        var steps = await HealthService().getTotalSteps(yesterday, now);
        var energy = await HealthService().getTotalActiveEnergy(yesterday, now);
        
        debugPrint("Sleep Hours: $sleepHours");
        debugPrint("Total Steps: $steps");
        debugPrint("Total Active Energy: $energy");

        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('睡眠時間: ${sleepHours?.toStringAsFixed(1) ?? "N/A"}時間, 歩数: $steps, エネルギー: ${energy.toStringAsFixed(2)}kcal')),
        );
      }
    } catch (e) {
      setState(() {
        _healthAuthStatusMessage = '権限リクエスト中にエラーが発生しました: $e';
      });
      debugPrint("Error during health auth or data fetch: $e");
    } finally {
      setState(() {
        _isRequestingHealthAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('ログインしていません。')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('パートナー連携'),
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

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                if (_isLoading) const Center(child: CircularProgressIndicator()),
                if (!_isLoading) ...[
                  Text('現在の連携ステータス: ${partnerLinkStatusToString(partnerLink?.status)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  // No link or invite declined
                  if (partnerLink == null || partnerLink.status == 'no_link' || partnerLink.status == 'invite_declined_by_partner' || partnerLink.status == 'invite_declined_by_you') ...[
                    const Text('パートナーと連携する'),
                    TextField(
                      controller: _partnerEmailController,
                      decoration: const InputDecoration(labelText: 'パートナーのメールアドレス'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: _sendInvite, child: const Text('招待を送信')),
                  ],
                  // Invite Sent
                  if (partnerLink?.status == 'invite_sent') ...[
                    Text('${partnerLink?.partnerEmail} さんに招待を送信しました。承認をお待ちください。'),
                     const SizedBox(height: 10),
                    TextButton(onPressed: () => _unlinkPartner(partnerLink!.linkedUserUid!), child: const Text('招待を取り消す', style: TextStyle(color: Colors.red))),
                  ],
                  // Invite Received
                  if (partnerLink?.status == 'invite_received' && partnerLink?.linkedUserUid != null) ...[
                    Text('${partnerLink?.inviterEmail} さんから連携リクエストが届いています。'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(onPressed: () => _acceptInvite(partnerLink!.linkedUserUid!), child: const Text('承認する')),
                        ElevatedButton(
                          onPressed: () => _declineInvite(partnerLink!.linkedUserUid!),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('拒否する', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                  // Linked
                  if (partnerLink?.status == 'linked' && partnerLink?.linkedUserUid != null) ...[
                    FutureBuilder<UserProfile?>(
                      future: _firestoreService.getUserProfile(partnerLink!.linkedUserUid!),
                      builder: (context, partnerSnapshot) {
                        if (partnerSnapshot.connectionState == ConnectionState.waiting) {
                          return const Text('連携相手の情報を取得中...');
                        }
                        if (partnerSnapshot.hasError || !partnerSnapshot.hasData || partnerSnapshot.data == null) {
                          return const Text('連携相手の情報を取得できませんでした。');
                        }
                        final partnerProfile = partnerSnapshot.data!;
                        return Text('${partnerProfile.displayName ?? partnerProfile.email} さんと連携済みです。');
                      }
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _unlinkPartner(partnerLink.linkedUserUid!),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('連携を解除する', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  // パートナー連携セクションとヘルスケア連携セクションの間に区切りとスペースを追加
                  const SizedBox(height: 20),
                  const Divider(thickness: 1),
                  const SizedBox(height: 20),

                  // ヘルスケアデータ連携セクション
                  const Text(
                    'ヘルスケアデータ連携',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_healthAuthStatusMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _healthAuthStatusMessage!,
                        style: TextStyle(color: _isHealthAuthorized ? Colors.green : Colors.orangeAccent),
                      ),
                    ),
                  if (!_isHealthAuthorized)
                    ElevatedButton(
                      onPressed: _isRequestingHealthAuth ? null : _requestHealthAuth,
                      child: _isRequestingHealthAuth 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Text('ヘルスケア連携をリクエスト'),
                    ),
                  if (_isHealthAuthorized)
                    const Text(
                      'ヘルスケアデータと連携済みです。',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  // コミュニケーションサポート機能セクション (連携済みの場合のみ表示)
                  if (partnerLink?.status == 'linked') ...[
                    const SizedBox(height: 20),
                    const Divider(thickness: 1),
                    const SizedBox(height: 20),
                    const Text(
                      'コミュニケーションサポート',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CommunicationAdviceScreen()),
                        );
                      },
                      child: const Text('コミュニケーションナビを使う'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PartnerAiChatScreen()),
                        );
                      },
                      child: const Text('AIチャット相談を使う'),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String partnerLinkStatusToString(String? status) {
    switch (status) {
      case 'no_link':
        return '未連携';
      case 'invite_sent':
        return '招待送信済み';
      case 'invite_received':
        return '招待受信済み';
      case 'linked':
        return '連携済み';
      case 'invite_declined_by_partner':
        return '招待がパートナーによって拒否されました';
       case 'invite_declined_by_you':
        return '招待を拒否しました';
      default:
        return '未連携';
    }
  }
}
