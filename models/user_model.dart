import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final PartnerLink? partnerLink;
  String? fcmToken; // Added FCM token field

  UserProfile({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
    this.partnerLink,
    this.fcmToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (partnerLink != null) 'partnerLink': partnerLink!.toMap(),
      if (fcmToken != null) 'fcmToken': fcmToken, // Added to map
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String documentId) {
    return UserProfile(
      uid: documentId,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
      partnerLink: map['partnerLink'] != null
          ? PartnerLink.fromMap(map['partnerLink'] as Map<String, dynamic>)
          : null,
      fcmToken: map['fcmToken'] as String?, // Added from map
    );
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    PartnerLink? partnerLink,
    String? fcmToken, // Added to copyWith
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      partnerLink: partnerLink ?? this.partnerLink,
      fcmToken: fcmToken ?? this.fcmToken, // Added to copyWith
    );
  }
}

class PartnerLink {
  final String? partnerEmail; // Email of the user they sent an invite to
  final String? inviterEmail; // Email of the user who sent them an invite
  final String? linkedUserUid; // UID of the linked partner
  String status; // e.g., 'no_link', 'invite_sent', 'invite_received', 'linked'

  PartnerLink({
    this.partnerEmail,
    this.inviterEmail,
    this.linkedUserUid,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      if (partnerEmail != null) 'partnerEmail': partnerEmail,
      if (inviterEmail != null) 'inviterEmail': inviterEmail,
      if (linkedUserUid != null) 'linkedUserUid': linkedUserUid,
      'status': status,
    };
  }

  factory PartnerLink.fromMap(Map<String, dynamic> map) {
    return PartnerLink(
      partnerEmail: map['partnerEmail'] as String?,
      inviterEmail: map['inviterEmail'] as String?,
      linkedUserUid: map['linkedUserUid'] as String?,
      status: map['status'] as String? ?? 'no_link',
    );
  }
}
