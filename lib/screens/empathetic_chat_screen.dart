import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mental_wellness_app/services/cloud_function_service.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class EmpatheticChatScreen extends StatefulWidget {
  const EmpatheticChatScreen({super.key});

  @override
  State<EmpatheticChatScreen> createState() => _EmpatheticChatScreenState();
}

class _ChatMessage {
  final String text;
  final String role; // 'user' or 'model'

  _ChatMessage({required this.text, required this.role});
}

class _EmpatheticChatScreenState extends State<EmpatheticChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add initial AI message with animation delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: "こんにちはワン♪ 今日はどんな一日だったワン？\n\nココロンはいつでも君のそばにいるから、何でもお話ししてほしいワン！\n\n嬉しいことも、悲しいことも、なんでも聞かせてね 🐾", 
            role: 'model',
          ));
        });
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = _ChatMessage(text: text, role: 'user');
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _textController.clear();

    // Prepare chat history for the Cloud Function
    // The Vertex AI API expects {role: 'user'/'model', parts: [{text: '...'}]}
    List<Map<String, dynamic>> historyForCF = _messages
        .where((m) => m != userMessage) // Exclude the current message being sent
        .map((m) => {
          'role': m.role, 
          'parts': [{'text': m.text}]
        })
        .toList();

    try {
      print('Sending message to AI: $text');
      print('Chat history: $historyForCF');
      
      final result = await _cloudFunctionService.getEmpatheticResponse(
        userMessage: text,
        chatHistory: historyForCF.isNotEmpty ? historyForCF : null,
      );
      
      print('AI Response received: $result');
      
      setState(() {
        _messages.add(_ChatMessage(
          text: result['aiResponse'] ?? 'うまく聞き取れませんでした。もう一度教えていただけますか？',
          role: 'model',
        ));
      });
    } catch (e) {
      print('Error in empathetic chat: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseFunctionsException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error details: ${e.details}');
      }
      
      setState(() {
        _messages.add(_ChatMessage(
          text: '申し訳ありません、エラーが発生しました: ${e.toString()}',
          role: 'model',
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('ココロンとおしゃべり'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          // ヘッダー部分（ココロンのウェルカムメッセージ）
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.brown.shade50,
                  Colors.orange.shade50,
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.brown.shade200,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ココロンの大きめの画像
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.brown.shade300,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.brown.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/character/character_main.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            '🐾',
                            style: TextStyle(fontSize: 40),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ココロンとおしゃべり',
                  style: TextStyle(
                    color: Colors.brown.shade800,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '🐾',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'あなたの気持ちに寄り添うワンちゃん',
                      style: TextStyle(
                        color: Colors.brown.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '🐾',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
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
                return AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 1.0,
                    child: _buildMessageBubble(message),
                  ),
                );
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
                    'ココロンが考えています...',
                    style: TextStyle(
                      color: Colors.brown.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ココロンのアバター（AIメッセージの場合のみ表示）
            if (!isUser) ...[
              _buildCocoronAvatar(),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isUser 
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withValues(alpha: 0.9),
                            ],
                          )
                        : null,
                      color: isUser ? null : Colors.white,
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
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      isUser ? 'あなた' : 'ココロン',
                      style: TextStyle(
                        color: AppTheme.textTertiaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ユーザーのアバター用スペース（右側メッセージの場合）
            if (isUser) const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildCocoronAvatar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.brown.shade100,
          border: Border.all(
            color: Colors.brown.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/character/character_main.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 画像が読み込めない場合は肉球アイコンを表示
              return Center(
                child: Text(
                  '🐾',
                  style: TextStyle(fontSize: 20),
                ),
              );
            },
          ),
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
                            hintText: 'どんなことでも話してください...',
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