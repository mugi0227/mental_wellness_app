import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/models/user_model.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';
import 'package:mental_wellness_app/screens/profile_check_wrapper.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  String _email = '';
  String _password = '';
  String _username = '';
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  void _trySubmit() async {
    print('Login button pressed'); // デバッグ用
    
    final isValid = _formKey.currentState?.validate();
    FocusScope.of(context).unfocus();
    
    print('Form validation result: $isValid'); // デバッグ用

    if (isValid != null && isValid) {
      _formKey.currentState?.save();
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });

      try {
        if (_isLogin) {
          print('Attempting to sign in with email: $_email'); // デバッグ用
          final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _email,
            password: _password,
          );
          print('Sign in successful: ${credential.user?.uid}'); // デバッグ用
          
          // ログイン成功後、手動で画面遷移
          if (mounted && credential.user != null) {
            // StreamBuilderが反応しない場合の対策として、直接ProfileCheckWrapperに遷移
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const ProfileCheckWrapper()),
              (route) => false,
            );
          }
        } else {
          final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _email,
            password: _password,
          );
          
          // Create a proper user profile
          final userProfile = UserProfile(
            uid: userCredential.user!.uid,
            email: _email,
            displayName: _username.isNotEmpty ? _username : _email.split('@')[0], // Use username or email prefix
            partnerLink: PartnerLink(status: 'no_link'),
            role: 'primary', // Default role
          );
          
          await _firestoreService.createUserProfile(userProfile);
          
          // サインアップ成功後も画面遷移
          if (mounted && userCredential.user != null) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const ProfileCheckWrapper()),
              (route) => false,
            );
          }
        }
        // Reset loading state on success (ログインの場合は遷移後なので実行されない)
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'email-already-in-use') {
          message = 'このメールアドレスは既に使用されています。';
        } else if (e.code == 'invalid-email') {
          message = 'メールアドレスの形式が正しくありません。';
        } else if (e.code == 'weak-password') {
          message = 'パスワードが弱すぎます。';
        } else if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          message = 'メールアドレスまたはパスワードが間違っています。';
        } else {
          message = '認証に失敗しました。もう一度お試しください。';
        }
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'エラーが発生しました。${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ロゴセクション
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite,
                    size: 60,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'メンタルウェルネス',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'あなたの心に寄り添うパートナー',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 40),
                // フォームカード
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.cardBorderRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            _isLogin ? 'ログイン' : 'アカウント作成',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // ユーザー名フィールド（サインアップ時のみ表示）
                          if (!_isLogin) ...[
                            TextFormField(
                              key: const ValueKey('username'),
                              decoration: const InputDecoration(
                                labelText: 'ユーザー名',
                                hintText: '表示される名前を入力',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'ユーザー名を入力してください。';
                                }
                                if (value.length > 20) {
                                  return 'ユーザー名は20文字以内で入力してください。';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _username = value!.trim();
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            key: const ValueKey('email'),
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'メールアドレス'),
                            validator: (value) {
                              if (value == null || !value.contains('@')) {
                                return '有効なメールアドレスを入力してください。';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _email = value!;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('password'),
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'パスワード'),
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return 'パスワードは6文字以上で入力してください。';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _password = value!;
                            },
                          ),
                          const SizedBox(height: 24),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _trySubmit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(_isLogin ? 'ログイン' : 'サインアップ'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _errorMessage = null;
                              });
                            },
                            child: Text(
                              _isLogin ? '新しいアカウントを作成' : 'ログインに戻る',
                              style: TextStyle(color: AppTheme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
