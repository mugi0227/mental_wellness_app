import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalInsight {
  final String insightId;
  final String userId;
  final Timestamp generatedDate;
  final Timestamp periodCoveredStart;
  final Timestamp periodCoveredEnd;
  final String summaryText;
  final List<String> keyObservations;
  final String positiveAffirmation;
  final Map<String, dynamic>? rawAIResponse; // Optional, for debugging or advanced use

  PersonalInsight({
    required this.insightId,
    required this.userId,
    required this.generatedDate,
    required this.periodCoveredStart,
    required this.periodCoveredEnd,
    required this.summaryText,
    required this.keyObservations,
    required this.positiveAffirmation,
    this.rawAIResponse,
  });

  // Factory constructor to create a PersonalInsight from a Firestore document
  factory PersonalInsight.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, String id) {
    final data = snapshot.data();
    if (data == null) {
      throw FirebaseException(
        plugin: 'Firestore',
        code: 'null-data',
        message: 'The data for document ${snapshot.id} was null.',
      );
    }

    return PersonalInsight(
      insightId: id,
      userId: data['userId'] as String? ?? '', // Provide default if null
      generatedDate: data['generatedDate'] as Timestamp? ?? Timestamp.now(), // Provide default
      periodCoveredStart: data['periodCoveredStart'] as Timestamp? ?? Timestamp.now(), // Provide default
      periodCoveredEnd: data['periodCoveredEnd'] as Timestamp? ?? Timestamp.now(), // Provide default
      summaryText: data['summaryText'] as String? ?? '', // Provide default
      keyObservations: List<String>.from(data['keyObservations'] as List<dynamic>? ?? []), // Provide default
      positiveAffirmation: data['positiveAffirmation'] as String? ?? '', // Provide default
      rawAIResponse: data['rawAIResponse'] as Map<String, dynamic>?, // Optional, can be null
    );
  }

  // Method to convert a PersonalInsight instance to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'generatedDate': generatedDate,
      'periodCoveredStart': periodCoveredStart,
      'periodCoveredEnd': periodCoveredEnd,
      'summaryText': summaryText,
      'keyObservations': keyObservations,
      'positiveAffirmation': positiveAffirmation,
      if (rawAIResponse != null) 'rawAIResponse': rawAIResponse,
    };
  }

  PersonalInsight copyWith({
    String? insightId,
    String? userId,
    Timestamp? generatedDate,
    Timestamp? periodCoveredStart,
    Timestamp? periodCoveredEnd,
    String? summaryText,
    List<String>? keyObservations,
    String? positiveAffirmation,
    Map<String, dynamic>? rawAIResponse,
  }) {
    return PersonalInsight(
      insightId: insightId ?? this.insightId,
      userId: userId ?? this.userId,
      generatedDate: generatedDate ?? this.generatedDate,
      periodCoveredStart: periodCoveredStart ?? this.periodCoveredStart,
      periodCoveredEnd: periodCoveredEnd ?? this.periodCoveredEnd,
      summaryText: summaryText ?? this.summaryText,
      keyObservations: keyObservations ?? this.keyObservations,
      positiveAffirmation: positiveAffirmation ?? this.positiveAffirmation,
      rawAIResponse: rawAIResponse ?? this.rawAIResponse,
    );
  }
}
