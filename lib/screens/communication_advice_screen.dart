import 'package:flutter/material.dart';
import 'package:mental_wellness_app/services/cloud_function_service.dart';

class CommunicationAdviceScreen extends StatefulWidget {
  const CommunicationAdviceScreen({super.key});

  @override
  State<CommunicationAdviceScreen> createState() =>
      _CommunicationAdviceScreenState();
}

class _CommunicationAdviceScreenState extends State<CommunicationAdviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _situationController = TextEditingController();
  final _queryController = TextEditingController();
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();

  bool _isLoading = false;
  String? _adviceText;
  List<String> _examplePhrases = [];
  String? _error;

  Future<void> _getAdvice() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _adviceText = null;
        _examplePhrases = [];
        _error = null;
      });

      try {
        final result = await _cloudFunctionService.getCommunicationAdvice(
          situation: _situationController.text,
          partnerQuery: _queryController.text.isNotEmpty
              ? _queryController.text
              : null,
        );
        setState(() {
          _adviceText = result['adviceText'] as String?;
          _examplePhrases = List<String>.from(result['examplePhrases'] ?? []);
          if (_adviceText == null || _adviceText!.isEmpty) {
            _adviceText = "具体的なアドバイスが見つかりませんでした。入力内容を変えてお試しください。";
          }
        });
      } catch (e) {
        setState(() {
          _error = 'アドバイスの取得中にエラーが発生しました: ${e.toString()}';
        });
      } finally {
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
        title: const Text('コミュニケーションナビ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'パートナー（ご本人）とのコミュニケーションで困っている状況や、具体的な悩み・質問を入力してください。AIがサポートのためのアドバイスや会話例を提案します。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _situationController,
                decoration: const InputDecoration(
                  labelText: '状況 *',
                  hintText: '例：最近、パートナーが落ち込んでいるように見える',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '状況を入力してください';
                  }
                  return null;
                },
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _queryController,
                decoration: const InputDecoration(
                  labelText: '具体的な悩みや質問 (任意)',
                  hintText: '例：どんな言葉をかけたら良いかわからない',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _getAdvice,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : const Text('アドバイスをもらう'),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (_adviceText != null) ...[
                Text(
                  'AIからのアドバイス：',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      _adviceText!,
                       style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ],
              if (_examplePhrases.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '会話例・行動提案：',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _examplePhrases
                          .map((phrase) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Expanded(child: Text(phrase, style: Theme.of(context).textTheme.bodyLarge)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
