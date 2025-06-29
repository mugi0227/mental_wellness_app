class DailyEvent {
  final String id;
  final String label;
  final String emoji;
  final String category;
  final bool isPositive; // ポジティブな出来事かどうか
  final bool isCustom; // カスタムイベントかどうか

  const DailyEvent({
    required this.id,
    required this.label,
    required this.emoji,
    required this.category,
    required this.isPositive,
    this.isCustom = false, // デフォルトは事前定義イベント
  });

  static const List<DailyEvent> predefinedEvents = [
    // ポジティブな出来事
    DailyEvent(id: 'good_meal', label: '美味しい食事', emoji: '🍽️', category: 'life', isPositive: true),
    DailyEvent(id: 'exercise', label: '運動', emoji: '🏃‍♀️', category: 'health', isPositive: true),
    DailyEvent(id: 'good_weather', label: 'いい天気', emoji: '☀️', category: 'nature', isPositive: true),
    DailyEvent(id: 'friend_chat', label: '友人との会話', emoji: '💬', category: 'social', isPositive: true),
    DailyEvent(id: 'achievement', label: '達成感', emoji: '🏆', category: 'work', isPositive: true),
    DailyEvent(id: 'good_sleep', label: 'よく眠れた', emoji: '😴', category: 'health', isPositive: true),
    DailyEvent(id: 'reading', label: '読書', emoji: '📚', category: 'hobby', isPositive: true),
    DailyEvent(id: 'music', label: '音楽鑑賞', emoji: '🎵', category: 'hobby', isPositive: true),
    
    // ニュートラル/少しネガティブな出来事
    DailyEvent(id: 'busy_day', label: '忙しい一日', emoji: '😅', category: 'work', isPositive: false),
    DailyEvent(id: 'rainy_day', label: '雨の日', emoji: '🌧️', category: 'nature', isPositive: false),
    DailyEvent(id: 'tired', label: '疲れた', emoji: '😪', category: 'health', isPositive: false),
    DailyEvent(id: 'stress', label: 'ストレス', emoji: '😤', category: 'work', isPositive: false),
    DailyEvent(id: 'loneliness', label: '寂しさ', emoji: '😔', category: 'social', isPositive: false),
    DailyEvent(id: 'worry', label: '心配事', emoji: '😰', category: 'mental', isPositive: false),
  ];
}