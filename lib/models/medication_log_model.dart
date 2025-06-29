import 'package:cloud_firestore/cloud_firestore.dart';

enum MedicationIntakeStatus { taken, skipped, missed, pending }

// Helper to convert enum to string for Firestore
String medicationIntakeStatusToString(MedicationIntakeStatus status) {
  return status.toString().split('.').last;
}

// Helper to convert string from Firestore to enum
MedicationIntakeStatus medicationIntakeStatusFromString(String? statusString) {
  if (statusString == null) return MedicationIntakeStatus.pending;
  return MedicationIntakeStatus.values.firstWhere(
    (e) => e.toString().split('.').last == statusString,
    orElse: () => MedicationIntakeStatus.pending,
  );
}

class MedicationLog {
  final String? id;
  final String userId;
  final String medicationId; // Links to the Medication document
  final String medicationName; // Denormalized for easier display
  final Timestamp scheduledIntakeTime; // Renamed from expectedIntakeTime for clarity
  final Timestamp? actualIntakeTime; // When it was actually marked as taken
  final MedicationIntakeStatus status;
  final String? notes;
  final Timestamp loggedAt; // Timestamp of when this log entry was created/updated

  MedicationLog({
    this.id,
    required this.userId,
    required this.medicationId,
    required this.medicationName,
    required this.scheduledIntakeTime,
    this.actualIntakeTime,
    required this.status,
    this.notes,
    required this.loggedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'scheduledIntakeTime': scheduledIntakeTime,
      'actualIntakeTime': actualIntakeTime,
      'status': medicationIntakeStatusToString(status), // Store enum as string
      'notes': notes,
      'loggedAt': loggedAt,
    };
  }

  factory MedicationLog.fromMap(Map<String, dynamic> map, String documentId) {
    return MedicationLog(
      id: documentId,
      userId: map['userId'] as String,
      medicationId: map['medicationId'] as String,
      medicationName: map['medicationName'] as String? ?? '', // Handle potential null
      scheduledIntakeTime: map['scheduledIntakeTime'] as Timestamp? ?? map['expectedIntakeTime'] as Timestamp? ?? Timestamp.now(), // Migration for old field name
      actualIntakeTime: map['actualIntakeTime'] as Timestamp?,
      status: medicationIntakeStatusFromString(map['status'] as String?),
      notes: map['notes'] as String?,
      loggedAt: map['loggedAt'] as Timestamp? ?? Timestamp.now(), // Handle potential null
    );
  }

  MedicationLog copyWith({
    String? id,
    String? userId,
    String? medicationId,
    String? medicationName,
    Timestamp? scheduledIntakeTime,
    Timestamp? actualIntakeTime,
    MedicationIntakeStatus? status,
    String? notes,
    Timestamp? loggedAt,
  }) {
    return MedicationLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      medicationId: medicationId ?? this.medicationId,
      medicationName: medicationName ?? this.medicationName,
      scheduledIntakeTime: scheduledIntakeTime ?? this.scheduledIntakeTime,
      actualIntakeTime: actualIntakeTime ?? this.actualIntakeTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }
}
