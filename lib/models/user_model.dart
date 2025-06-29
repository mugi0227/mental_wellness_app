class UserProfile {
  final String uid;
  final String email;
  String? displayName;
  PartnerLink? partnerLink;
  // 'primary' (当事者) or 'partner' (パートナー)
  String? role;
  final String? photoURL; // Added for Firebase Auth compatibility 

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.partnerLink,
    this.role,
    this.photoURL,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String documentId) {
    return UserProfile(
      uid: documentId,
      email: data['email'] ?? '',
      displayName: data['displayName'] as String?,
      partnerLink: data['partnerLink'] != null
          ? PartnerLink.fromMap(data['partnerLink'] as Map<String, dynamic>)
          : null,
      role: data['role'] as String?,
      photoURL: data['photoURL'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      if (displayName != null) 'displayName': displayName,
      if (partnerLink != null) 'partnerLink': partnerLink!.toMap(),
      if (role != null) 'role': role,
      if (photoURL != null) 'photoURL': photoURL,
    };
  }
}

class PartnerLink {
  // For Primary User: partnerUid will be the UID of the partner they invited or are linked with.
  // For Partner User: linkedUserUid will be the UID of the primary user who invited them or they are linked with.
  String? linkedUserUid; // UID of the other user in the link
  String? partnerEmail; // Email of the user they sent an invite to (used by primary user initially)
  String? inviterEmail; // Email of the user who sent invite (used by partner user initially)
  // status: 'no_link', 'invite_sent', 'invite_received', 'linked', 'invite_declined_by_partner', 'invite_declined_by_you'
  String status;

  PartnerLink({
    this.linkedUserUid,
    this.partnerEmail,
    this.inviterEmail,
    required this.status,
  });

  factory PartnerLink.fromMap(Map<String, dynamic> data) {
    return PartnerLink(
      linkedUserUid: data['linkedUserUid'] as String?,
      partnerEmail: data['partnerEmail'] as String?,
      inviterEmail: data['inviterEmail'] as String?,
      status: data['status'] ?? 'no_link',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (linkedUserUid != null) 'linkedUserUid': linkedUserUid,
      if (partnerEmail != null) 'partnerEmail': partnerEmail,
      if (inviterEmail != null) 'inviterEmail': inviterEmail,
      'status': status,
    };
  }
}
