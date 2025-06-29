import 'package:cloud_firestore/cloud_firestore.dart';

enum SleepQuality {
  veryPoor,
  poor,
  fair,
  good,
  veryGood,
}

String sleepQualityToString(SleepQuality quality) {
  switch (quality) {
    case SleepQuality.veryPoor:
      return '非常に悪い';
    case SleepQuality.poor:
      return '悪い';
    case SleepQuality.fair:
      return '普通';
    case SleepQuality.good:
      return '良い';
    case SleepQuality.veryGood:
      return '非常に良い';
    default:
      return '不明';
  }
}

SleepQuality sleepQualityFromString(String? qualityString) {
  switch (qualityString) {
    case '非常に悪い':
      return SleepQuality.veryPoor;
    case '悪い':
      return SleepQuality.poor;
    case '普通':
      return SleepQuality.fair;
    case '良い':
      return SleepQuality.good;
    case '非常に良い':
      return SleepQuality.veryGood;
    default:
      return SleepQuality.fair; // Default or consider throwing an error
  }
}

class SleepLog {
  final String? id;
  final String userId;
  final DateTime dateOfSleep; // Which night this log refers to (e.g., night of 2023-10-26)
  final Timestamp sleepStartTime;
  final Timestamp sleepEndTime;
  final double? durationHours; // Calculated or manually entered
  final SleepQuality sleepQuality;
  final int? awakenings; // Number of times woken up
  final String? notes;
  final Timestamp createdAt;

  SleepLog({
    this.id,
    required this.userId,
    required this.dateOfSleep,
    required this.sleepStartTime,
    required this.sleepEndTime,
    this.durationHours,
    required this.sleepQuality,
    this.awakenings,
    this.notes,
    required this.createdAt,
  });

  factory SleepLog.fromMap(Map<String, dynamic> map, String id) {
    return SleepLog(
      id: id,
      userId: map['userId'] as String,
      dateOfSleep: (map['dateOfSleep'] as Timestamp).toDate(),
      sleepStartTime: map['sleepStartTime'] as Timestamp,
      sleepEndTime: map['sleepEndTime'] as Timestamp,
      durationHours: map['durationHours'] as double?,
      sleepQuality: sleepQualityFromString(map['sleepQuality'] as String?),
      awakenings: map['awakenings'] as int?,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'userId': userId,
      'dateOfSleep': Timestamp.fromDate(dateOfSleep),
      'sleepStartTime': sleepStartTime,
      'sleepEndTime': sleepEndTime,
      'sleepQuality': sleepQualityToString(sleepQuality),
      'createdAt': createdAt,
    };
    if (durationHours != null) {
      data['durationHours'] = durationHours;
    }
    if (awakenings != null) {
      data['awakenings'] = awakenings;
    }
    if (notes != null && notes!.isNotEmpty) {
      data['notes'] = notes;
    }
    return data;
  }

  SleepLog copyWith({
    String? id,
    String? userId,
    DateTime? dateOfSleep,
    Timestamp? sleepStartTime,
    Timestamp? sleepEndTime,
    double? durationHours,
    SleepQuality? sleepQuality,
    int? awakenings,
    String? notes,
    Timestamp? createdAt,
  }) {
    return SleepLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dateOfSleep: dateOfSleep ?? this.dateOfSleep,
      sleepStartTime: sleepStartTime ?? this.sleepStartTime,
      sleepEndTime: sleepEndTime ?? this.sleepEndTime,
      durationHours: durationHours ?? this.durationHours,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      awakenings: awakenings ?? this.awakenings,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Calculated property for sleep duration
  double get calculatedDurationHours {
    if (durationHours != null) return durationHours!;
    if (sleepEndTime.toDate().isAfter(sleepStartTime.toDate())) {
      return (sleepEndTime.microsecondsSinceEpoch - sleepStartTime.microsecondsSinceEpoch) / (1000 * 1000 * 60 * 60);
    }
    return 0.0;
  }
}
