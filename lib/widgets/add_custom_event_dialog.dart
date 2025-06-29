import 'package:flutter/material.dart';
import '../models/daily_event_model.dart';
import '../core/theme/app_theme.dart';

class AddCustomEventDialog extends StatefulWidget {
  final Function(DailyEvent) onEventAdded;

  const AddCustomEventDialog({
    super.key,
    required this.onEventAdded,
  });

  @override
  State<AddCustomEventDialog> createState() => _AddCustomEventDialogState();
}

class _AddCustomEventDialogState extends State<AddCustomEventDialog> {
  final _labelController = TextEditingController();
  String _selectedEmoji = '😊';
  String _selectedCategory = 'life';
  bool _isPositive = true;

  // よく使われる絵文字のリスト
  final List<String> _commonEmojis = [
    '😊', '😂', '😍', '🥰', '😎', '🤔', '😴', '😋',
    '🎉', '🎊', '🎈', '🎁', '🏆', '⭐', '💖', '💝',
    '🌟', '🌈', '☀️', '🌙', '🌸', '🌺', '🌻', '🌷',
    '🍕', '🍰', '🍦', '☕', '🎵', '🎨', '📚', '🎮',
    '💪', '🏃‍♀️', '🧘‍♀️', '🏋️‍♂️', '🚶‍♀️', '🛌', '🛁', '💤',
    '💼', '📱', '💻', '✈️', '🚗', '🏠', '🎓', '💡',
  ];

  final List<String> _categories = [
    'life', 'health', 'work', 'social', 'hobby', 'nature', 'mental'
  ];

  final Map<String, String> _categoryLabels = {
    'life': '生活',
    'health': '健康',
    'work': '仕事',
    'social': '社会',
    'hobby': '趣味',
    'nature': '自然',
    'mental': 'メンタル',
  };

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _saveEvent() {
    if (_labelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ラベルを入力してください')),
      );
      return;
    }

    final event = DailyEvent(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: _labelController.text.trim(),
      emoji: _selectedEmoji,
      category: _selectedCategory,
      isPositive: _isPositive,
    );

    widget.onEventAdded(event);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // タイトルバー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'カスタムイベントを追加',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // コンテンツ部分
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ラベル入力
                    TextField(
                      controller: _labelController,
                      decoration: const InputDecoration(
                        labelText: 'イベント名',
                        hintText: '例: 映画鑑賞、散歩、読書',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 絵文字選択
                    const Text('絵文字を選択:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(4),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          childAspectRatio: 1,
                        ),
                        itemCount: _commonEmojis.length,
                        itemBuilder: (context, index) {
                          final emoji = _commonEmojis[index];
                          final isSelected = emoji == _selectedEmoji;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedEmoji = emoji;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : null,
                                borderRadius: BorderRadius.circular(4),
                                border: isSelected 
                                    ? Border.all(color: AppTheme.primaryColor, width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // カテゴリー選択
                    const Text('カテゴリー:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(_categoryLabels[category] ?? category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // ポジティブ/ネガティブ選択
                    const Text('種類:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('ポジティブ'),
                            subtitle: const Text('良い出来事'),
                            value: true,
                            groupValue: _isPositive,
                            onChanged: (value) {
                              setState(() {
                                _isPositive = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('ニュートラル'),
                            subtitle: const Text('普通の出来事'),
                            value: false,
                            groupValue: _isPositive,
                            onChanged: (value) {
                              setState(() {
                                _isPositive = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ボタン部分
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('追加'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}