import 'package:flutter/material.dart';

class AiCharacterWidget extends StatefulWidget {
  final String? message;
  final bool showMessage;
  final String characterName;
  final VoidCallback? onTap; // タップコールバックを追加
  
  const AiCharacterWidget({
    super.key,
    this.message,
    this.showMessage = true,
    this.characterName = 'ココロン',
    this.onTap,
  });

  @override
  State<AiCharacterWidget> createState() => _AiCharacterWidgetState();
}

class _AiCharacterWidgetState extends State<AiCharacterWidget>
    with TickerProviderStateMixin {
  late AnimationController _messageAnimationController;
  late Animation<double> _messageScaleAnimation;
  late Animation<double> _messageOpacityAnimation;
  bool _isMessageVisible = true; // 吹き出しの表示状態を管理

  @override
  void initState() {
    super.initState();
    
    // 初期状態を設定
    _isMessageVisible = widget.showMessage;
    
    // メッセージポップアップ用のアニメーション
    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800), // 期間を少し長くして滑らかに
      vsync: this,
    );
    
    _messageScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _messageAnimationController,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInCubic, // より滑らかな消えるアニメーション
    ));

    _messageOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _messageAnimationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut), // 表示時は遅めに透明度変化
      reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic), // 消える時は全期間でゆっくりフェード
    ));

    // 初回表示時にメッセージアニメーションを開始
    if (widget.showMessage && _isMessageVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messageAnimationController.forward();
      });
    }
  }

  @override
  void dispose() {
    _messageAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AiCharacterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showMessage != oldWidget.showMessage) {
      _isMessageVisible = widget.showMessage;
      if (widget.showMessage && _isMessageVisible) {
        _messageAnimationController.forward();
      } else {
        _messageAnimationController.reverse();
      }
    }
  }
  
  // 吹き出しの表示/非表示を切り替えるメソッド
  void _toggleMessage() {
    setState(() {
      _isMessageVisible = !_isMessageVisible;
    });
    
    if (_isMessageVisible) {
      _messageAnimationController.forward();
    } else {
      _messageAnimationController.reverse();
    }
    
    // 外部のコールバックを呼び出し
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // キャラクター本体（下のレイヤー）
        Positioned(
          bottom: -30,
          right: -10,
          child: GestureDetector(
            onTap: _toggleMessage,
            child: _buildCharacter(),
          ),
        ),
        
        // メッセージ吹き出し（上のレイヤー）
        if (widget.showMessage && widget.message != null && _isMessageVisible)
          Positioned(
            bottom: 10, // キャラクターの口元あたり
            right: 150, // キャラクターの左側
            child: GestureDetector(
              onTap: _toggleMessage,
              child: _buildMessageBubble(widget.message!),
            ),
          ),
      ],
    );
  }

  Widget _buildCharacter() {
    return Container(
      width: 195,
      height: 195,
      child: ClipOval(
        child: Image.asset(
          'assets/images/character/character_main.png',
          width: 195,
          height: 195,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 画像が見つからない場合のフォールバック
            return _buildFallbackCharacter();
          },
        ),
      ),
    );
  }

  Widget _buildFallbackCharacter() {
    // 画像が読み込めない場合の代替キャラクター（ワンちゃん）
    return Container(
      width: 195,
      height: 195,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.brown.shade300,
            Colors.brown.shade400,
          ],
        ),
      ),
      child: const Icon(
        Icons.pets,
        size: 100,
        color: Colors.white,
      ),
    );
  }


  Widget _buildMessageBubble(String message) {
    return AnimatedBuilder(
      animation: _messageAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _messageScaleAnimation.value,
          child: Opacity(
            opacity: _messageOpacityAnimation.value,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.brown.shade100,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // キャラクター名
                  Text(
                    widget.characterName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.brown.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // メッセージ
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}