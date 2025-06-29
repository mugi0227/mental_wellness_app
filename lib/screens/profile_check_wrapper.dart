import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/models/user_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/screens/main_screen.dart';
import 'package:mental_wellness_app/screens/auth_screen.dart';
import 'package:mental_wellness_app/utils/fix_user_profiles.dart';

class ProfileCheckWrapper extends StatefulWidget {
  const ProfileCheckWrapper({super.key});

  @override
  State<ProfileCheckWrapper> createState() => _ProfileCheckWrapperState();
}

class _ProfileCheckWrapperState extends State<ProfileCheckWrapper> {
  bool _isCreatingProfile = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final user = authSnapshot.data;
        if (user == null) {
          // ユーザーがログアウトした場合、AuthScreenに戻る
          return const AuthScreen();
        }

        final firestoreService = FirestoreService();

        return StreamBuilder<UserProfile?>(
      stream: firestoreService.userProfileStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('エラーが発生しました: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Try to create profile for existing user
                      _createProfileForExistingUser(context, user, firestoreService);
                    },
                    child: const Text('プロファイルを作成'),
                  ),
                ],
              ),
            ),
          );
        }

        // If profile doesn't exist or is incomplete, create it
        if (!snapshot.hasData || snapshot.data == null) {
          // Auto-create profile for existing users (only once)
          if (!_isCreatingProfile) {
            _isCreatingProfile = true;
            _createProfileForExistingUser(context, user, firestoreService);
          }
          
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('プロファイルを作成中...'),
                ],
              ),
            ),
          );
        }

        // Profile exists, fix email if needed and proceed to main screen
        // 非同期でメールアドレスを修正
        fixUserProfileEmail();
        
        return const MainScreen();
        },
      );
      },
    );
  }

  Future<void> _createProfileForExistingUser(
    BuildContext context,
    User user,
    FirestoreService firestoreService,
  ) async {
    try {
      // Check if profile already exists
      final existingProfile = await firestoreService.getUserProfile(user.uid);
      if (existingProfile != null) {
        return; // Profile already exists
      }

      // Create a new profile for existing user
      final userProfile = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? user.email?.split('@')[0] ?? 'ユーザー',
        partnerLink: PartnerLink(status: 'no_link'),
        role: 'primary', // Default role
        photoURL: user.photoURL,
      );

      await firestoreService.createUserProfile(userProfile);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プロファイルを作成しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error creating user profile: $e');
      if (mounted) {
        setState(() {
          _isCreatingProfile = false; // Reset flag on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('プロファイルの作成に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}