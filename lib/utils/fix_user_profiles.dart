import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/models/user_model.dart';

/// 既存ユーザーのプロファイルにメールアドレスがない場合、追加する
Future<void> fixUserProfileEmail() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) return;

  final firestoreService = FirestoreService();
  final profile = await firestoreService.getUserProfile(user.uid);
  
  if (profile != null && (profile.email.isEmpty || profile.email != user.email)) {
    print('Updating profile email from "${profile.email}" to "${user.email}"');
    
    // プロファイルを更新
    final updatedProfile = UserProfile(
      uid: profile.uid,
      email: user.email!, // Firebase Authからメールアドレスを取得
      displayName: profile.displayName,
      partnerLink: profile.partnerLink,
      role: profile.role,
      photoURL: profile.photoURL,
    );
    
    await firestoreService.updateUserProfile(updatedProfile);
    print('Profile email updated successfully');
  }
}