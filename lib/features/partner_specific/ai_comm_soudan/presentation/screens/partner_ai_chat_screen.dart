import 'package:flutter/material.dart';
import 'package:mental_wellness_app/services/cloud_function_service.dart';

// Message model for chat
class ChatMessage {
  final String text;
  final bool isUser; // true if the user sent the message, false if it's an AI message
  final String? disclaimer; // Optional disclaimer text for AI messages

  ChatMessage({required this.text, required this.isUser, this.disclaimer});
}

class PartnerAiChatScreen extends StatefulWidget {
  final String? supportedUserId; // サポート対象のユーザーID
  
  const PartnerAiChatScreen({
    super.key,
    this.supportedUserId,
  });

  @override
  State<PartnerAiChatScreen> createState() => _PartnerAiChatScreenState();
}

class _PartnerAiChatScreenState extends State<PartnerAiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();
  final List<ChatMessage> _messages = []; // List to hold chat messages
  bool _isLoading = false; // To show a loading indicator while AI is responding
  final ScrollController _scrollController = ScrollController(); // To auto-scroll to the latest message

  @override
  void initState() {
    super.initState();
    // Add an initial AI message with a welcome and disclaimer
    _messages.add(ChatMessage(
      text: "パートナーの方とのコミュニケーションに関するお悩みや、具体的な声かけの方法など、お気軽にご相談ください。AIが一緒に考え、アドバイスを提供します。",
      isUser: false,
      disclaimer: "このAIによる回答は、一般的な情報提供や提案を目的としており、専門的なカウンセリングや医学的なアドバイスに代わるものではありません。深刻な悩みや精神的な問題については、専門家にご相談ください。"
    ));
  }

  void _scrollToBottom() {
    // Scrolls to the bottom of the list after a short delay to allow UI to update
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessageText = text.trim();
    _textController.clear();

    // Add user message to the list
    setState(() {
      _messages.add(ChatMessage(text: userMessageText, isUser: true));
      _isLoading = true; // Show loading indicator
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());


    // Prepare chat history for the Cloud Function
    List<Map<String, String>> historyForFunction = _messages
        .where((m) => m.text != userMessageText || !m.isUser) // Exclude the current user message being sent
        .map((m) => {'role': m.isUser ? 'user' : 'model', 'text': m.text})
        .toList();

    try {
      // Call the Cloud Function
      final result = await _cloudFunctionService.getPartnerChatAdvice(
        userMessage: userMessageText,
        chatHistory: historyForFunction.isNotEmpty ? historyForFunction : null,
      );

      // Add AI response to the list
      if (result['aiResponse'] != null) {
        setState(() {
          _messages.add(ChatMessage(
            text: result['aiResponse'] as String,
            isUser: false,
            // Use disclaimer from function if available, otherwise default
            disclaimer: result['disclaimer'] as String? ?? "このAIによる回答は、一般的な情報提供や提案を目的としており、専門的なカウンセリングや医学的なアドバイスに代わるものではありません。深刻な悩みや精神的な問題については、専門家にご相談ください。"
          ));
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(text: 'AIからの応答がありませんでした。', isUser: false, disclaimer: "エラーが発生しました。しばらくしてから再度お試しください。"));
        });
      }
    } catch (e) {
      // Handle errors
      setState(() {
        _messages.add(ChatMessage(text: 'エラーが発生しました: ${e.toString()}', isUser: false, disclaimer: "このAIによる回答は、一般的な情報提供や提案を目的としており、専門的なカウンセリングや医学的なアドバイスに代わるものではありません。深刻な悩みや精神的な問題については、専門家にご相談ください。"));
      });
      debugPrint('Error calling getPartnerChatAdvice: $e');
    } finally {
      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI相談チャット (パートナー様向け)'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              // reverse: true, // Display messages from bottom to top; handled by scroll controller and adding to end of list
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(),
            ),
          // Text input area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'AIへの相談内容を入力...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    ),
                    onSubmitted: _isLoading ? null : _sendMessage,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : () => _sendMessage(_textController.text),
                  color: Theme.of(context).primaryColor,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds individual message bubbles
  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Max width for bubbles
        decoration: BoxDecoration(
          color: message.isUser ? Theme.of(context).primaryColorLight.withOpacity(0.9) : Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(color: message.isUser ? Colors.black87 : Colors.black87, fontSize: 16),
            ),
            if (message.disclaimer != null && message.disclaimer!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  message.disclaimer!,
                  style: TextStyle(fontSize: 10.0, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
