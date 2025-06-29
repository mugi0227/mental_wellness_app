import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/models/user_model.dart';

/// Firebase Authに存在するがFirestoreにプロファイルがないユーザーのプロファイルを作成
Future<void> createMissingUserProfile(String email) async {
  final firestoreService = FirestoreService();
  
  // まず既存のプロファイルを確認
  final existingProfile = await firestoreService.findUserByEmail(email);
  if (existingProfile != null) {
    print('Profile already exists for $email');
    return;
  }
  
  // Firebase AuthのユーザーIDを取得する必要がある
  // 注：通常はCloud Functionsで実装すべきですが、
  // 一時的な解決策として、そのユーザーでログインしてプロファイルを作成してもらう必要があります
  
  print('Profile does not exist for $email');
  print('Please ask the user to log in with this email to create their profile.');
}

/// 現在のユーザーのプロファイルを確実に作成
Future<void> ensureCurrentUserProfile() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) return;
  
  final firestoreService = FirestoreService();
  final profile = await firestoreService.getUserProfile(user.uid);
  
  if (profile == null) {
    print('Creating profile for current user: ${user.email}');
    
    final newProfile = UserProfile(
      uid: user.uid,
      email: user.email!,
      displayName: user.displayName ?? user.email!.split('@')[0],
      partnerLink: PartnerLink(status: 'no_link'),
      role: 'primary',
      photoURL: user.photoURL,
    );
    
    await firestoreService.createUserProfile(newProfile);
    print('Profile created successfully');
  } else {
    print('Profile already exists for current user');
  }
}