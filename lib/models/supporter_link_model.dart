import 'package:cloud_firestore/cloud_firestore.dart';

/// 複数サポーター対応のための新しい連携モデル
class SupporterLink {
  final String id; // ドキュメントID
  final String userId; // 当事者のUID
  final String supporterId; // サポーターのUID
  final String supporterEmail; // サポーターのメール
  final String? supporterDisplayName; // サポーターの表示名
  final SupporterLinkStatus status; // 連携状態
  final DateTime createdAt; // 作成日時
  final DateTime? acceptedAt; // 承認日時
  final DateTime? declinedAt; // 拒否日時
  final SupporterPermissions permissions; // 権限設定

  SupporterLink({
    required this.id,
    required this.userId,
    required this.supporterId,
    required this.supporterEmail,
    this.supporterDisplayName,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.declinedAt,
    required this.permissions,
  });

  factory SupporterLink.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupporterLink(
      id: doc.id,
      userId: data['userId'] ?? '',
      supporterId: data['supporterId'] ?? '',
      supporterEmail: data['supporterEmail'] ?? '',
      supporterDisplayName: data['supporterDisplayName'] as String?,
      status: SupporterLinkStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => SupporterLinkStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      acceptedAt: data['acceptedAt'] != null
          ? (data['acceptedAt'] as Timestamp).toDate()
          : null,
      declinedAt: data['declinedAt'] != null
          ? (data['declinedAt'] as Timestamp).toDate()
          : null,
      permissions: SupporterPermissions.fromMap(
        data['permissions'] ?? SupporterPermissions.defaultPermissions().toMap(),
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'supporterId': supporterId,
      'supporterEmail': supporterEmail,
      if (supporterDisplayName != null) 'supporterDisplayName': supporterDisplayName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (declinedAt != null) 'declinedAt': Timestamp.fromDate(declinedAt!),
      'permissions': permissions.toMap(),
    };
  }

  SupporterLink copyWith({
    String? id,
    String? userId,
    String? supporterId,
    String? supporterEmail,
    String? supporterDisplayName,
    SupporterLinkStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? declinedAt,
    SupporterPermissions? permissions,
  }) {
    return SupporterLink(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      supporterId: supporterId ?? this.supporterId,
      supporterEmail: supporterEmail ?? this.supporterEmail,
      supporterDisplayName: supporterDisplayName ?? this.supporterDisplayName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      declinedAt: declinedAt ?? this.declinedAt,
      permissions: permissions ?? this.permissions,
    );
  }
}

/// サポーター連携の状態
enum SupporterLinkStatus {
  pending, // 招待送信済み（承認待ち）
  accepted, // 承認済み（連携中）
  declined, // 拒否済み
  removed, // 削除済み
}

/// サポーターの権限設定
class SupporterPermissions {
  final bool canViewMentalWeather; // ココロの天気予報を見れるか
  final bool canViewMoodScore; // 気分スコアを見れるか
  final bool canViewMoodGraph; // 気分グラフを見れるか
  final bool canReceiveNotifications; // 通知を受け取るか
  final bool canUseAIChat; // AIチャット相談を使えるか

  SupporterPermissions({
    required this.canViewMentalWeather,
    required this.canViewMoodScore,
    required this.canViewMoodGraph,
    required this.canReceiveNotifications,
    required this.canUseAIChat,
  });

  factory SupporterPermissions.defaultPermissions() {
    return SupporterPermissions(
      canViewMentalWeather: true,
      canViewMoodScore: true,
      canViewMoodGraph: true,
      canReceiveNotifications: false,
      canUseAIChat: true,
    );
  }

  factory SupporterPermissions.fromMap(Map<String, dynamic> data) {
    return SupporterPermissions(
      canViewMentalWeather: data['canViewMentalWeather'] ?? true,
      canViewMoodScore: data['canViewMoodScore'] ?? true,
      canViewMoodGraph: data['canViewMoodGraph'] ?? true,
      canReceiveNotifications: data['canReceiveNotifications'] ?? false,
      canUseAIChat: data['canUseAIChat'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canViewMentalWeather': canViewMentalWeather,
      'canViewMoodScore': canViewMoodScore,
      'canViewMoodGraph': canViewMoodGraph,
      'canReceiveNotifications': canReceiveNotifications,
      'canUseAIChat': canUseAIChat,
    };
  }

  SupporterPermissions copyWith({
    bool? canViewMentalWeather,
    bool? canViewMoodScore,
    bool? canViewMoodGraph,
    bool? canReceiveNotifications,
    bool? canUseAIChat,
  }) {
    return SupporterPermissions(
      canViewMentalWeather: canViewMentalWeather ?? this.canViewMentalWeather,
      canViewMoodScore: canViewMoodScore ?? this.canViewMoodScore,
      canViewMoodGraph: canViewMoodGraph ?? this.canViewMoodGraph,
      canReceiveNotifications: canReceiveNotifications ?? this.canReceiveNotifications,
      canUseAIChat: canUseAIChat ?? this.canUseAIChat,
    );
  }
}