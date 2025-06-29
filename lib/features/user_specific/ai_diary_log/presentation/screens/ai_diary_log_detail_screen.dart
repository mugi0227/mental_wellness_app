import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/models/ai_diary_log_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
// import 'package:mental_wellness_app/services/cloud_function_service.dart'; // 不要になるためコメントアウト

class AiDiaryLogDetailScreen extends StatefulWidget {
  final AiDiaryLog log;

  const AiDiaryLogDetailScreen({super.key, required this.log});

  @override
  State<AiDiaryLogDetailScreen> createState() => _AiDiaryLogDetailScreenState();
}

class _AiDiaryLogDetailScreenState extends State<AiDiaryLogDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  // final CloudFunctionService _cloudFunctionService = CloudFunctionService(); // 不要

  // String? _aiComment; // initStateで直接 widget.log.aiComment を使うため不要
  // bool _isLoadingAiComment = false; // 不要
  // String? _aiCommentError; // 不要

  @override
  void initState() {
    super.initState();
    // _aiComment = widget.log.aiComment; // 表示時に直接 widget.log.aiComment を参照
    // 動的取得ロジッ���は削除
  }

  // _fetchAiComment メソッド全体を削除

  Future<void> _deleteLog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしていません。')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('日記の削除'),
          content: const Text('この日記を本当に削除しますか？この操作は取り消せません。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('削除', style: TextStyle(color: Colors.red[700])),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteAiDiaryLog(user.uid, widget.log.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日��を削除しました。')),
        );
        if (mounted) {
           Navigator.of(context).pop();
        }
      } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('日記の削除中にエラーが発生しました: $e')),
           );
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedTimestamp(DateTime ts) {
      return DateFormat('yyyy年MM月dd日 HH:mm').format(ts);
    }

    IconData moodIcon;
    Color moodColor;
    String moodText;

    switch (widget.log.selfReportedMoodScore) {
      case 1:
        moodIcon = Icons.sentiment_very_dissatisfied;
        moodColor = Colors.red;
        moodText = '最悪';
        break;
      case 2:
        moodIcon = Icons.sentiment_dissatisfied;
        moodColor = Colors.orange;
        moodText = '悪い';
        break;
      case 3:
        moodIcon = Icons.sentiment_neutral;
        moodColor = Colors.grey;
        moodText = '普通';
        break;
      case 4:
        moodIcon = Icons.sentiment_satisfied;
        moodColor = Colors.lightGreen;
        moodText = '良い';
        break;
      case 5:
        moodIcon = Icons.sentiment_very_satisfied;
        moodColor = Colors.green;
        moodText = '最高';
        break;
      default:
        moodIcon = Icons.help_outline;
        moodColor = Colors.grey;
        moodText = '不明 (${widget.log.selfReportedMoodScore})';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(formattedTimestamp(widget.log.timestamp.toDate())),
        backgroundColor: Colors.green[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: '日記を削除',
            onPressed: () => _deleteLog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                Icon(moodIcon, size: 30, color: moodColor),
                const SizedBox(width: 8),
                Text(
                  '気分: $moodText (${widget.log.selfReportedMoodScore}/5)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: moodColor),
                ),
              ],
            ),
            if (widget.log.overallMoodScore != null && widget.log.overallMoodScore != widget.log.selfReportedMoodScore)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '総合気分スコア (AI分析後): ${widget.log.overallMoodScore?.toStringAsFixed(1)}/5',
                  style: TextStyle(fontSize: 14, color: Colors.blueGrey[700]),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '記録日時: ${formattedTimestamp(widget.log.timestamp.toDate())}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            if (widget.log.diaryText != null && widget.log.diaryText!.isNotEmpty) ...[
              Text(
                '日記:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800]),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.green[200]!)
                ),
                child: Text(
                  widget.log.diaryText!,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // AIコメントセクション
            Text(
              'AIからのコメント:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800]),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.blue[200]!)
              ),
              child: (widget.log.aiComment != null && widget.log.aiComment!.isNotEmpty)
                  ? Text(
                      widget.log.aiComment!,
                      style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, height: 1.5),
                    )
                  : Text(
                      (widget.log.diaryText == null || widget.log.diaryText!.isEmpty)
                          ? '日記の記録がないため、AIコメントは表示されません。' // 日記自体がない場合
                          : 'AIコメントはありません。', // 日記はあるがAIコメントがない場合
                      style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
