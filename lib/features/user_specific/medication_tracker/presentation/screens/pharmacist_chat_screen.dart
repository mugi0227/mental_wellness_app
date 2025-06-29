import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/services/cloud_function_service.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PharmacistChatScreen extends StatefulWidget {
  const PharmacistChatScreen({super.key});

  @override
  State<PharmacistChatScreen> createState() => _PharmacistChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final String? disclaimer;

  _ChatMessage({required this.text, required this.isUser, this.disclaimer});
}

class _PharmacistChatScreenState extends State<PharmacistChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();
  final FirestoreService _firestoreService = FirestoreService();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  List<String> _currentMedicationNames = [];

  @override
  void initState() {
    super.initState();
    _fetchMedicationContext();
    // Add initial AI message
    _messages.add(_ChatMessage(
      text: "こんにちは💊 お薬に関するご質問をお気軽にどうぞ。\n一般的な情報を提供させていただきます。", 
      isUser: false,
      disclaimer: "このAIによる回答は、一般的な情報提供のみを目的としており、医学的なアドバイスに代わるものではありません。具体的な症状や治療法、薬の服用に関しては、必ず医師または薬剤師にご相談ください。"
    ));
  }

  Future<void> _fetchMedicationContext() async {
    if (_userId == null) return;
    try {
      final medications = await _firestoreService.getMedicationsStream(_userId!).first;
      if(mounted){
        setState(() {
          _currentMedicationNames = medications.map((m) => m.name).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching medication context: $e");
      // Handle error if needed, maybe show a snackbar
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _userId == null) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _textController.clear();

    // Prepare chat history for context (excluding the current message)
    List<Map<String, dynamic>> historyForCF = _messages
        .where((m) => m.text != text) // Exclude current message
        .map((m) => {
          'role': m.isUser ? 'user' : 'model',
          'parts': [{'text': m.text}]
        })
        .toList();

    try {
      print('Sending pharmacist query: $text');
      print('Current medications: $_currentMedicationNames');
      print('Chat history: $historyForCF');
      
      final result = await _cloudFunctionService.getPharmacistAdvice(
        query: text,
        medicationContext: _currentMedicationNames.isNotEmpty ? _currentMedicationNames : null,
        chatHistory: historyForCF.isNotEmpty ? historyForCF : null,
      );
      
      print('Pharmacist AI Response received: $result');
      
      if(mounted){
        setState(() {
          _messages.add(_ChatMessage(
            text: result['advice'] ?? '情報を取得できませんでした。',
            isUser: false,
            disclaimer: result['disclaimer'] ?? '',
          ));
        });
      }
    } catch (e) {
      print('Error in pharmacist chat: $e');
      print('Error type: ${e.runtimeType}');
      
      if(mounted){
        setState(() {
          _messages.add(_ChatMessage(
              text: 'エラーが発生しました: ${e.toString()}',
              isUser: false,
              disclaimer: "このAIによる回答は、一般的な情報提供のみを目的としており、医学的なアドバイスに代わるものではありません。具体的な症状や治療法、薬の服用に関しては、必ず医師または薬剤師にご相談ください。"
          ));
        });
      }
    } finally {
      if(mounted){
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('AI薬剤師相談'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          // ヘッダー部分
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.medical_services,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'お薬に関する一般的な情報を提供します',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              reverse: true, // To show latest messages at the bottom
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages.reversed.toList()[index]; // Display in reverse order
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI薬剤師が調べています...',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          _buildTextComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser 
                  ? AppTheme.primaryColor
                  : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  strong: TextStyle(
                    color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                  em: TextStyle(
                    color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                    fontStyle: FontStyle.italic,
                  ),
                  listBullet: TextStyle(
                    color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                  ),
                  h1: TextStyle(
                    color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: TextStyle(
                    color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: TextStyle(
                    color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  code: TextStyle(
                    backgroundColor: isUser 
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
                    color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                    fontFamily: 'monospace',
                  ),
                  blockquote: TextStyle(
                    color: isUser ? Colors.white.withValues(alpha: 0.8) : AppTheme.textSecondaryColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            ),
            if (message.disclaimer != null && message.disclaimer!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message.disclaimer!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isUser ? 'あなた' : 'AI薬剤師',
                style: TextStyle(
                  color: AppTheme.textTertiaryColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.textTertiaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          onSubmitted: _isLoading ? null : _sendMessage,
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'お薬について質問する...',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondaryColor,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(
                            Icons.send,
                            color: _isLoading 
                              ? AppTheme.textTertiaryColor
                              : AppTheme.primaryColor,
                          ),
                          onPressed: _isLoading 
                            ? null 
                            : () => _sendMessage(_textController.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
