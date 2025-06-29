import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String? id;
  final String userId;
  final String name;
  final String dosage; // e.g., "1 tablet", "10mg"
  final String form; // e.g., "Tablet", "Capsule", "Liquid"
  final String frequency; // e.g., "Daily", "Twice a day", "As needed"
  final List<String> times; // e.g., ["08:00", "20:00"], or specific labels like "Morning", "Bedtime"
  final Timestamp? startDate; // Optional start date
  final Timestamp? endDate;   // Optional end date
  final bool reminderEnabled;
  final String? notes;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  Medication({
    this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.form,
    required this.frequency,
    required this.times,
    this.startDate,
    this.endDate,
    this.reminderEnabled = true,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'form': form,
      'frequency': frequency,
      'times': times,
      'startDate': startDate,
      'endDate': endDate,
      'reminderEnabled': reminderEnabled,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(), // Set on update
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map, String documentId) {
    return Medication(
      id: documentId,
      userId: map['userId'] as String,
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      form: map['form'] as String? ?? 'Tablet', // Default form if not present
      frequency: map['frequency'] as String,
      times: List<String>.from(map['times'] as List<dynamic>),
      startDate: map['startDate'] as Timestamp?,
      endDate: map['endDate'] as Timestamp?,
      reminderEnabled: map['reminderEnabled'] as bool? ?? true,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as Timestamp,
      updatedAt: map['updatedAt'] as Timestamp?,
    );
  }

  Medication copyWith({
    String? id,
    String? userId,
    String? name,
    String? dosage,
    String? form,
    String? frequency,
    List<String>? times,
    Timestamp? startDate,
    Timestamp? endDate,
    bool? reminderEnabled,
    String? notes,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      form: form ?? this.form,
      frequency: frequency ?? this.frequency,
      times: times ?? this.times,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
