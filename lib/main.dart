import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart'; // DateFormatの日本語ロケール初期化のため
import 'package:flutter_dotenv/flutter_dotenv.dart'; // dotenv for environment variables
import 'package:mental_wellness_app/screens/auth_screen.dart';
import 'package:mental_wellness_app/screens/main_screen.dart'; // MainScreenをインポート
import 'package:mental_wellness_app/screens/partner_link_screen.dart'; // PartnerLinkScreenをインポート
import 'package:mental_wellness_app/screens/profile_check_wrapper.dart'; // ProfileCheckWrapperをインポート
import 'package:mental_wellness_app/features/partner_specific/ai_comm_soudan/presentation/screens/partner_ai_chat_screen.dart';
import 'package:mental_wellness_app/services/notification_service.dart'; // NotificationServiceをインポート
import 'package:mental_wellness_app/services/local_notification_service.dart'; // LocalNotificationServiceをインポート
import 'package:mental_wellness_app/core/theme/app_theme.dart'; // AppThemeをインポート

// Global navigator key to access navigator from outside widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Load environment variables
  await Firebase.initializeApp(); // Firebase initialization restored
  await initializeDateFormatting('ja_JP', null); // 日本語ロケールの初期化
  await NotificationService().initialize(); // NotificationServiceを初期化
  await LocalNotificationService().initialize(); // LocalNotificationServiceを初期化
  
  // デバッグ用: 現在のユーザー状態を確認
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    print('Already logged in user: ${currentUser.uid}');
    print('Email: ${currentUser.email}');
  } else {
    print('No user currently logged in');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Pass the navigatorKey
      title: 'Mental Wellness App',
      theme: AppTheme.lightTheme(),
      routes: {
        '/partner_link': (context) => const PartnerLinkScreen(),
        '/partner_ai_chat': (context) => const PartnerAiChatScreen(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, userSnapshot) {
          print('Auth state changed: ${userSnapshot.connectionState}, hasData: ${userSnapshot.hasData}, user: ${userSnapshot.data?.uid}');
          
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          if (userSnapshot.hasError) {
            print('StreamBuilder error: ${userSnapshot.error}');
            return Scaffold(
              body: Center(
                child: Text('エラーが発生しました: ${userSnapshot.error}'),
              ),
            );
          }
          
          if (userSnapshot.hasData && userSnapshot.data != null) {
            print('User is logged in: ${userSnapshot.data!.uid}, navigating to ProfileCheckWrapper');
            return const ProfileCheckWrapper();
          }
          
          print('No user logged in, showing AuthScreen');
          return const AuthScreen(); // ログイン前の認証画面
        },
      ),
    );
  }
}