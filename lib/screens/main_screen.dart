import 'package:flutter/material.dart';
import 'package:mental_wellness_app/features/user_specific/ai_diary_log/presentation/screens/ai_diary_log_screen.dart';
import 'package:mental_wellness_app/features/user_specific/mood_graph/presentation/screens/mood_graph_screen.dart';
import 'package:mental_wellness_app/features/shared_features/communication_hub/presentation/screens/communication_hub_screen_v3.dart';
import 'package:mental_wellness_app/features/user_specific/medication_tracker/presentation/screens/medication_list_screen.dart'; // MedicationListScreenをインポート
import 'package:mental_wellness_app/screens/other_options_screen.dart';
import 'package:mental_wellness_app/widgets/ai_character_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? _moodGraphForecastMessage; // 気分グラフタブの動的メッセージ

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const AiDiaryLogScreen(), // 日記
      MoodGraphScreen(
        onForecastMessageChanged: (message) {
          if (mounted) {
            setState(() {
              _moodGraphForecastMessage = message;
            });
          }
        },
      ), // 気分グラフ
      const CommunicationHubScreenV3(), // コミュニケーション
      const MedicationListScreen(), // お薬手帳
      const OtherOptionsScreen(), // その他
    ];
  }

  // タブ別ココロンメッセージ
  final List<String> _kokoronMessages = [
    "今日はどんな気分だワン？", // 日記
    "気分の変化を一緒に見てるよ♪", // 気分グラフ
    "みんなでサポートしあおうね！", // つながり
    "お薬の時間を忘れずにワン", // お薬
    "何かお手伝いできることあるワン？", // メニュー
  ];


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getCurrentKokoronMessage() {
    // 気分グラフタブでMindForecastメッセージがある場合はそれを使用
    if (_selectedIndex == 1 && _moodGraphForecastMessage != null) {
      return _moodGraphForecastMessage!;
    }
    return _kokoronMessages[_selectedIndex];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBarは各画面で定義するため、ここでは不要
      // appBar: AppBar(
      //   title: Text(_screenTitles[_selectedIndex], style: TextStyle(color: Colors.white)),
      //   backgroundColor: Colors.green[700], // 落ち着いた緑色
      // ),
      body: Stack(
        children: [
          // メイン画面コンテンツ
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          // ココロンキャラクター（常時表示）
          AiCharacterWidget(
            message: _getCurrentKokoronMessage(),
            showMessage: true,
            characterName: 'ココロン',
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book),
              label: '日記',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart),
              activeIcon: Icon(Icons.show_chart),
              label: '気分',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined),
              activeIcon: Icon(Icons.forum),
              label: 'つながり',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medication_outlined),
              activeIcon: Icon(Icons.medication),
              label: 'お薬',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.apps_outlined),
              activeIcon: Icon(Icons.apps),
              label: 'メニュー',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
