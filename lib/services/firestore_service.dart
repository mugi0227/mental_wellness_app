import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mental_wellness_app/models/user_model.dart';
import 'package:mental_wellness_app/models/ai_diary_log_model.dart';
import 'package:mental_wellness_app/models/medication_model.dart'; // Add Medication model
import 'package:mental_wellness_app/models/medication_log_model.dart'; // Add MedicationLog model
import 'package:mental_wellness_app/models/personal_insight_model.dart'; // Add PersonalInsight model
import 'package:mental_wellness_app/models/sleep_log_model.dart'; // Add SleepLog model
import 'package:mental_wellness_app/models/supporter_link_model.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // User Profile
  Future<void> createUserProfile(UserProfile userProfile) async {
    try {
      await _db
          .collection('users')
          .doc(userProfile.uid)
          .set(userProfile.toMap());
    } catch (e) {
      debugPrint('Error creating user profile: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
    return null;
  }

  Future<void> updateUserProfile(UserProfile userProfile) async {
    try {
      await _db
          .collection('users')
          .doc(userProfile.uid)
          .update(userProfile.toMap());
    } catch (e) {
      debugPrint('Error updating user profile: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
  }

  // 【追加したメソッド】FCMトークンを保存するための機能
  Future<void> saveUserFCMToken(String userId, String? token) async {
    if (token == null) return; // トークンがなければ何もしない
    try {
      await _db.collection('users').doc(userId).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving FCM token: $e'); // TODO: Use a proper logger or analytics in production
      // ここではrethrowしない。トークンの保存失敗が他の処理を妨げないように。
    }
  }

  // Partner Linking
  Future<UserProfile?> findUserByEmail(String email) async {
    try {
      debugPrint('Searching for user with email: $email');
      
      QuerySnapshot query = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
          
      debugPrint('Found ${query.docs.length} users with email: $email');
      
      if (query.docs.isNotEmpty) {
        final userData = query.docs.first.data() as Map<String, dynamic>;
        debugPrint('User data: $userData');
        
        return UserProfile.fromMap(userData, query.docs.first.id);
      }
    } catch (e) {
      debugPrint('Error finding user by email: $e'); // TODO: Use a proper logger or analytics in production
    }
    return null;
  }

  Future<void> sendPartnerInvite(String inviterUid, String inviteeEmail) async {
    UserProfile? inviteeProfile = await findUserByEmail(inviteeEmail);
    if (inviteeProfile == null) {
      throw Exception('招待相手のメールアドレスが見つかりませんでした。');
    }

    UserProfile? inviterProfile = await getUserProfile(inviterUid);
    if (inviterProfile == null) {
      throw Exception('招待者のプロファイルが見つかりませんでした。');
    }

    // Update inviter's profile
    inviterProfile.partnerLink = PartnerLink(
      partnerEmail: inviteeEmail,
      linkedUserUid: inviteeProfile.uid, // Store potential partner's UID
      status: 'invite_sent',
    );
    await updateUserProfile(inviterProfile);

    // Update invitee's profile
    inviteeProfile.partnerLink = PartnerLink(
      inviterEmail: inviterProfile.email,
      linkedUserUid: inviterUid, // Store inviter's UID
      status: 'invite_received',
    );
    await updateUserProfile(inviteeProfile);
  }

  Future<void> acceptPartnerInvite(
      String accepterUid, String inviterUid) async {
    UserProfile? accepterProfile = await getUserProfile(accepterUid);
    UserProfile? inviterProfile = await getUserProfile(inviterUid);

    if (accepterProfile == null || inviterProfile == null) {
      throw Exception('ユーザープロファイルが見つかりません。');
    }

    // Update accepter's profile
    accepterProfile.partnerLink?.status = 'linked';
    accepterProfile.partnerLink?.inviterEmail =
        null; // Clear inviter email as link is established
    accepterProfile.partnerLink?.linkedUserUid = inviterUid;
    await updateUserProfile(accepterProfile);

    // Update inviter's profile
    inviterProfile.partnerLink?.status = 'linked';
    inviterProfile.partnerLink?.partnerEmail =
        null; // Clear partner email as link is established
    inviterProfile.partnerLink?.linkedUserUid = accepterUid;
    await updateUserProfile(inviterProfile);
  }

  Future<void> declinePartnerInvite(
      String declinerUid, String otherUserUid) async {
    UserProfile? declinerProfile = await getUserProfile(declinerUid);
    UserProfile? otherUserProfile = await getUserProfile(otherUserUid);

    if (declinerProfile == null || otherUserProfile == null) {
      throw Exception('ユーザープロファイルが見つかりません。');
    }

    // Mark decliner's status
    declinerProfile.partnerLink =
        PartnerLink(status: 'no_link'); // Reset or set specific declined status
    await updateUserProfile(declinerProfile);

    // Mark other user's status (the one who sent or would have received)
    otherUserProfile.partnerLink =
        PartnerLink(status: 'no_link'); // Reset or set specific declined status
    await updateUserProfile(otherUserProfile);
  }

  Future<void> unlinkPartner(String userUid, String partnerUid) async {
    UserProfile? userProfile = await getUserProfile(userUid);
    UserProfile? partnerProfile = await getUserProfile(partnerUid);

    if (userProfile == null || partnerProfile == null) {
      throw Exception('ユーザープロファイルが見つかりません。');
    }

    userProfile.partnerLink = PartnerLink(status: 'no_link');
    await updateUserProfile(userProfile);

    partnerProfile.partnerLink = PartnerLink(status: 'no_link');
    await updateUserProfile(partnerProfile);
  }

  Stream<UserProfile?> userProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return UserProfile.fromMap(
            snapshot.data() as Map<String, dynamic>, snapshot.id);
      }
      return null;
    });
  }

  // Mood Logs
  Future<void> addAiDiaryLog(AiDiaryLog aiDiaryLog) async {
    try {
      await _db
          .collection('users')
          .doc(aiDiaryLog.userId)
          .collection('aiDiaryLogs') // Collection name changed
          .add(aiDiaryLog.toMap());
    } catch (e) {
      debugPrint('Error adding mood log: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
  }

  Stream<List<AiDiaryLog>> getAiDiaryLogsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('aiDiaryLogs') // Collection name changed
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AiDiaryLog.fromMap(doc.data() as Map<String, dynamic>, doc.id)) // Cast added
            .toList());
  }

  Future<void> deleteAiDiaryLog(String userId, String logId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('aiDiaryLogs')
          .doc(logId)
          .delete();
      debugPrint('Successfully deleted AiDiaryLog: $logId for user: $userId');
    } catch (e) {
      debugPrint('Error deleting AiDiaryLog: $e');
      rethrow;
    }
  }

  // Medication CRUD
  Future<DocumentReference> addMedication(Medication medication) async {
    try {
      return await _db
          .collection('users')
          .doc(medication.userId)
          .collection('medications')
          .add(medication.toMap());
    } catch (e) {
      debugPrint('Error adding medication: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
  }

  Future<void> updateMedication(Medication medication) async {
    try {
      await _db
          .collection('users')
          .doc(medication.userId)
          .collection('medications')
          .doc(medication.id)
          .update(medication.toMap());
    } catch (e) {
      debugPrint('Error updating medication: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
  }

  Future<void> deleteMedication(String userId, String medicationId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medicationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting medication: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
  }

  Stream<List<Medication>> getMedicationsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('medications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Medication.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Medication Log
  Future<void> addMedicationLog(MedicationLog medicationLog) async {
    try {
      await _db
          .collection('users')
          .doc(medicationLog.userId)
          .collection('medicationLogs')
          .add(medicationLog.toMap());
    } catch (e) {
      debugPrint('Error adding medication log: $e'); // TODO: Use a proper logger or analytics in production
      rethrow;
    }
  }

  Stream<List<MedicationLog>> getMedicationLogsStream(String userId, {DateTime? date}) {
    Query query = _db
        .collection('users')
        .doc(userId)
        .collection('medicationLogs')
        .orderBy('scheduledIntakeTime', descending: true);

    if (date != null) {
      final startOfDay = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
      final endOfDay = Timestamp.fromDate(DateTime(date.year, date.month, date.day, 23, 59, 59));
      query = query.where('scheduledIntakeTime', isGreaterThanOrEqualTo: startOfDay)
                   .where('scheduledIntakeTime', isLessThanOrEqualTo: endOfDay);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => MedicationLog.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList())
        .handleError((error) {
          debugPrint('Error in getMedicationLogsStream: $error');
          if (error.toString().contains('requires an index')) {
            debugPrint('Firestore index required. Please check the console for the index creation link.');
          }
          throw error;
        });
  }

  Future<void> updateMedicationLog(MedicationLog medicationLog) async {
    try {
      await _db
          .collection('users')
          .doc(medicationLog.userId)
          .collection('medicationLogs')
          .doc(medicationLog.id)
          .update(medicationLog.toMap());
    } catch (e) {
      debugPrint('Error updating medication log: $e');
      rethrow;
    }
  }

  Future<void> deleteMedicationLog(String userId, String medicationLogId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('medicationLogs')
          .doc(medicationLogId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting medication log: $e');
      rethrow;
    }
  }

  // Personal Insights
  Stream<List<PersonalInsight>> getPersonalInsightsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('personalInsights')
        .orderBy('generatedDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PersonalInsight.fromFirestore(doc, doc.id))
            .toList());
  }

  // Sleep Logs
  Future<void> addSleepLog(SleepLog sleepLog) async {
    try {
      await _db
          .collection('users')
          .doc(sleepLog.userId)
          .collection('sleepLogs')
          .add(sleepLog.toMap());
    } catch (e) {
      debugPrint('Error adding sleep log: $e');
      rethrow;
    }
  }

  Stream<List<SleepLog>> getSleepLogsStream(String userId, {DateTime? specificDate}) {
    Query query = _db
        .collection('users')
        .doc(userId)
        .collection('sleepLogs')
        .orderBy('dateOfSleep', descending: true);

    if (specificDate != null) {
      final startOfDay = Timestamp.fromDate(DateTime(specificDate.year, specificDate.month, specificDate.day));
      final endOfDay = Timestamp.fromDate(DateTime(specificDate.year, specificDate.month, specificDate.day, 23, 59, 59, 999, 999));
      query = query.where('dateOfSleep', isGreaterThanOrEqualTo: startOfDay)
                   .where('dateOfSleep', isLessThanOrEqualTo: endOfDay);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => SleepLog.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<void> updateSleepLog(SleepLog sleepLog) async {
    try {
      await _db
          .collection('users')
          .doc(sleepLog.userId)
          .collection('sleepLogs')
          .doc(sleepLog.id)
          .update(sleepLog.toMap());
    } catch (e) {
      debugPrint('Error updating sleep log: $e');
      rethrow;
    }
  }

  Future<void> deleteSleepLog(String userId, String sleepLogId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('sleepLogs')
          .doc(sleepLogId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting sleep log: $e');
      rethrow;
    }
  }

  // ========== 複数サポーター連携機能 ==========

  /// サポーター招待を送信
  Future<void> sendSupporterInvite({
    required String userId,
    required String supporterEmail,
  }) async {
    try {
      // 招待先のユーザーを検索
      final supporterUser = await findUserByEmail(supporterEmail);
      if (supporterUser == null) {
        throw Exception('指定されたメールアドレスのユーザーが見つかりません');
      }

      // 既存の連携をチェック
      final existingLink = await _db
          .collection('supporterLinks')
          .where('userId', isEqualTo: userId)
          .where('supporterId', isEqualTo: supporterUser.uid)
          .get();

      if (existingLink.docs.isNotEmpty) {
        final status = existingLink.docs.first.data()['status'];
        if (status == 'accepted') {
          throw Exception('既に連携済みです');
        } else if (status == 'pending') {
          throw Exception('既に招待を送信済みです');
        }
      }

      // 新しい連携リンクを作成
      final newLink = SupporterLink(
        id: '', // Firestoreが自動生成
        userId: userId,
        supporterId: supporterUser.uid,
        supporterEmail: supporterEmail,
        supporterDisplayName: supporterUser.displayName,
        status: SupporterLinkStatus.pending,
        createdAt: DateTime.now(),
        permissions: SupporterPermissions.defaultPermissions(),
      );

      await _db.collection('supporterLinks').add(newLink.toFirestore());
    } catch (e) {
      debugPrint('Error sending supporter invite: $e');
      rethrow;
    }
  }

  /// ユーザーのサポーターリストを取得（ストリーム）
  Stream<List<SupporterLink>> getUserSupportersStream(String userId) {
    return _db
        .collection('supporterLinks')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          final supporters = docs
              .map((doc) => SupporterLink.fromFirestore(doc))
              .toList();
          // クライアント側でソート
          supporters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return supporters;
        });
  }

  /// サポーターが関連する当事者リストを取得（ストリーム）
  Stream<List<SupporterLink>> getSupporterLinksStream(String supporterId) {
    return _db
        .collection('supporterLinks')
        .where('supporterId', isEqualTo: supporterId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          final links = docs
              .map((doc) => SupporterLink.fromFirestore(doc))
              .toList();
          // クライアント側でソート（acceptedAtがnullの場合はcreatedAtを使用）
          links.sort((a, b) {
            final aDate = a.acceptedAt ?? a.createdAt;
            final bDate = b.acceptedAt ?? b.createdAt;
            return bDate.compareTo(aDate);
          });
          return links;
        });
  }

  /// 受信した招待リストを取得（ストリーム）
  Stream<List<SupporterLink>> getPendingInvitesStream(String supporterId) {
    return _db
        .collection('supporterLinks')
        .where('supporterId', isEqualTo: supporterId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          final invites = docs
              .map((doc) => SupporterLink.fromFirestore(doc))
              .toList();
          // クライアント側でソート
          invites.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return invites;
        });
  }

  /// サポーター招待を承認（相互サポーター関係を作成）
  Future<void> acceptSupporterInvite(String linkId) async {
    try {
      // 既存の招待を取得
      final linkDoc = await _db.collection('supporterLinks').doc(linkId).get();
      if (!linkDoc.exists) {
        throw Exception('招待が見つかりません');
      }
      
      final link = SupporterLink.fromFirestore(linkDoc);
      
      // 1. 既存の招待を承認
      await _db.collection('supporterLinks').doc(linkId).update({
        'status': SupporterLinkStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      // 2. 逆方向の関係が既に存在するかチェック
      final reverseLink = await _db
          .collection('supporterLinks')
          .where('userId', isEqualTo: link.supporterId)
          .where('supporterId', isEqualTo: link.userId)
          .get();
      
      if (reverseLink.docs.isEmpty) {
        // 3. 逆方向の関係を作成（承認者も相手のサポーターになる）
        final reverseSupporterLink = SupporterLink(
          id: '', // Firestoreが自動生成
          userId: link.supporterId, // 承認者が当事者
          supporterId: link.userId, // 招待者がサポーター
          supporterEmail: (await getUserProfile(link.userId))?.email ?? '',
          supporterDisplayName: (await getUserProfile(link.userId))?.displayName,
          status: SupporterLinkStatus.accepted, // 自動的に承認済み
          createdAt: DateTime.now(),
          acceptedAt: DateTime.now(),
          permissions: SupporterPermissions.defaultPermissions(),
        );
        
        await _db.collection('supporterLinks').add(reverseSupporterLink.toFirestore());
        debugPrint('相互サポーター関係を作成しました');
      }
    } catch (e) {
      debugPrint('Error accepting supporter invite: $e');
      rethrow;
    }
  }

  /// サポーター招待を拒否
  Future<void> declineSupporterInvite(String linkId) async {
    try {
      await _db.collection('supporterLinks').doc(linkId).update({
        'status': SupporterLinkStatus.declined.name,
        'declinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error declining supporter invite: $e');
      rethrow;
    }
  }

  /// サポーター連携を削除（相互関係も削除）
  Future<void> removeSupporterLink(String linkId) async {
    try {
      // 既存のリンクを取得
      final linkDoc = await _db.collection('supporterLinks').doc(linkId).get();
      if (!linkDoc.exists) {
        throw Exception('連携が見つかりません');
      }
      
      final link = SupporterLink.fromFirestore(linkDoc);
      
      // 1. 現在のリンクを削除状態に更新
      await _db.collection('supporterLinks').doc(linkId).update({
        'status': SupporterLinkStatus.removed.name,
      });
      
      // 2. 逆方向の関係も削除
      final reverseLink = await _db
          .collection('supporterLinks')
          .where('userId', isEqualTo: link.supporterId)
          .where('supporterId', isEqualTo: link.userId)
          .where('status', isEqualTo: SupporterLinkStatus.accepted.name)
          .get();
      
      for (var doc in reverseLink.docs) {
        await _db.collection('supporterLinks').doc(doc.id).update({
          'status': SupporterLinkStatus.removed.name,
        });
        debugPrint('逆方向の連携も削除しました');
      }
    } catch (e) {
      debugPrint('Error removing supporter link: $e');
      rethrow;
    }
  }

  /// サポーターの権限を更新
  Future<void> updateSupporterPermissions(
    String linkId,
    SupporterPermissions permissions,
  ) async {
    try {
      await _db.collection('supporterLinks').doc(linkId).update({
        'permissions': permissions.toMap(),
      });
    } catch (e) {
      debugPrint('Error updating supporter permissions: $e');
      rethrow;
    }
  }

  /// 特定のサポーター連携情報を取得
  Future<SupporterLink?> getSupporterLink(String linkId) async {
    try {
      final doc = await _db.collection('supporterLinks').doc(linkId).get();
      if (doc.exists) {
        return SupporterLink.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error getting supporter link: $e');
      rethrow;
    }
    return null;
  }
}