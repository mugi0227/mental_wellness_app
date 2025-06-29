import 'package:flutter/material.dart';
import 'package:mental_wellness_app/services/cloud_function_service.dart';

class CommunicationAdviceScreen extends StatefulWidget {
  const CommunicationAdviceScreen({super.key});

  @override
  State<CommunicationAdviceScreen> createState() => _CommunicationAdviceScreenState();
}

class _CommunicationAdviceScreenState extends State<CommunicationAdviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();

  final TextEditingController _situationController = TextEditingController();
  final TextEditingController _queryController = TextEditingController();

  bool _isLoading = false;
  String? _adviceText;
  List<String> _examplePhrases = [];
  String? _errorText;

  Future<void> _getAdvice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _adviceText = null;
      _examplePhrases = [];
      _errorText = null;
    });

    try {
      final result = await _cloudFunctionService.getCommunicationAdvice(
        situation: _situationController.text,
        partnerQuery: _queryController.text.isNotEmpty ? _queryController.text : null,
      );
      if (mounted) {
        setState(() {
          _adviceText = result['adviceText'];
          _examplePhrases = List<String>.from(result['examplePhrases'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'アドバイスの取得中にエラーが発生しました: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _situationController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コミュニケーション支援'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'どのような状況でお困りですか？',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _situationController,
                decoration: const InputDecoration(
                  labelText: '状況を具体的に記述してください',
                  hintText: '例: 最近、パートナーが塞ぎ込んでいて、あまり話してくれません。',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '状況を入力してください。';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                '具体的な悩みや質問 (任意)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _queryController,
                decoration: const InputDecoration(
                  labelText: 'AIへの具体的な質問があれば入力',
                  hintText: '例: どのように声をかけるのが良いでしょうか？ 何かできることはありますか？',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lightbulb_outline),
                label: Text(_isLoading ? 'アドバイスを生成中...' : 'AIからアドバイスをもらう'),
                onPressed: _isLoading ? null : _getAdvice,
              ),
              const SizedBox(height: 24),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorText!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_adviceText != null)
                _buildAdviceSection(
                  title: '💡 AIからのアドバイス',
                  content: _adviceText!,
                  icon: Icons.message_outlined,
                  backgroundColor: Colors.blue.shade50,
                  borderColor: Colors.blue.shade200,
                ),
              if (_examplePhrases.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: _buildAdviceSection(
                    title: '🗣️ 会話例・行動提案',
                    contentWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _examplePhrases.map((phrase) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 18, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Expanded(child: Text(phrase, style: const TextStyle(fontSize: 15.5, height: 1.4))),
                          ],
                        ),
                      )).toList(),
                    ),
                    icon: Icons.record_voice_over_outlined,
                    backgroundColor: Colors.green.shade50,
                    borderColor: Colors.green.shade200,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdviceSection({
    required String title,
    String? content,
    Widget? contentWidget,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Card(
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: Theme.of(context).primaryColorDark),
                const SizedBox(width: 10.0),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            if (contentWidget != null)
              contentWidget
            else if (content != null)
              Text(
                content,
                style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                textAlign: TextAlign.justify,
              ),
          ],
        ),
      ),
    );
  }
}
