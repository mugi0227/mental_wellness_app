import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mental_wellness_app/models/medication_model.dart';
import 'package:mental_wellness_app/models/medication_log_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/core/theme/app_theme.dart';
import './medication_add_edit_screen.dart';
// import './pharmacist_chat_screen.dart'; // 薬剤師機能は共感チャットに統合されました
import 'package:mental_wellness_app/screens/empathetic_chat_screen.dart';

// Helper class to combine Medication and its logged status for a specific time
class _ScheduledIntake {
  final Medication medication;
  final TimeOfDay scheduledTimeOfDay;
  final Timestamp scheduledTimestamp; // Full timestamp for today
  MedicationLog? logEntry;
  MedicationIntakeStatus status;

  _ScheduledIntake({
    required this.medication,
    required this.scheduledTimeOfDay,
    required this.scheduledTimestamp,
    this.logEntry,
    this.status = MedicationIntakeStatus.pending,
  });
}

class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({super.key});

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: '表示する日付を選択',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _logMedicationIntake(_ScheduledIntake intake, MedicationIntakeStatus newStatus) async {
    if (_userId == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      MedicationLog logToSave;
      if (intake.logEntry != null) {
        // Update existing log
        logToSave = intake.logEntry!.copyWith(
          status: newStatus,
          actualIntakeTime: newStatus == MedicationIntakeStatus.taken ? Timestamp.now() : intake.logEntry!.actualIntakeTime,
          loggedAt: Timestamp.now(),
        );
        await _firestoreService.updateMedicationLog(logToSave);
      } else {
        // Create new log
        logToSave = MedicationLog(
          userId: _userId!,
          medicationId: intake.medication.id!,
          medicationName: intake.medication.name,
          scheduledIntakeTime: intake.scheduledTimestamp,
          actualIntakeTime: newStatus == MedicationIntakeStatus.taken ? Timestamp.now() : null,
          status: newStatus,
          loggedAt: Timestamp.now(),
        );
        await _firestoreService.addMedicationLog(logToSave);
      }
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('${intake.medication.name}を「${medicationIntakeStatusToString(newStatus)}」として記録しました。')));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('記録エラー: $e')));
    }
  }

  List<_ScheduledIntake> _prepareScheduledIntakes(List<Medication> medications, List<MedicationLog> logs) {
    final List<_ScheduledIntake> scheduledIntakes = [];
    final today = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    for (var med in medications) {
      // Filter medications active for the selected date
      bool isActive = true;
      if (med.startDate != null && med.startDate!.toDate().isAfter(today)) {
        isActive = false;
      }
      if (med.endDate != null && med.endDate!.toDate().isBefore(today)) {
        isActive = false;
      }
      if (!isActive) continue;

      for (var timeStr in med.times) {
        try {
          final parts = timeStr.split(':');
          final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          final scheduledTimestamp = Timestamp.fromDate(DateTime(today.year, today.month, today.day, time.hour, time.minute));
          
          MedicationLog? existingLog = logs.firstWhere(
            (log) => log.medicationId == med.id && log.scheduledIntakeTime.seconds == scheduledTimestamp.seconds, // Compare by seconds for precision
            orElse: () => MedicationLog( // Placeholder if not found, so logEntry is not null if no actual log
              userId: _userId!, 
              medicationId: med.id!,
              medicationName: med.name,
              scheduledIntakeTime: scheduledTimestamp,
              status: MedicationIntakeStatus.pending,
              loggedAt: Timestamp.now(), // Dummy value, won't be saved unless an action is taken
            ),
          );

          // Determine if the found log is a real one or a placeholder
          MedicationIntakeStatus currentStatus = MedicationIntakeStatus.pending;
          MedicationLog? actualLogEntry; // Will be null if no real log exists for this scheduled time

          bool logIsReal = logs.any((log) => log.medicationId == med.id && log.scheduledIntakeTime.seconds == scheduledTimestamp.seconds);
          if(logIsReal){
            actualLogEntry = existingLog;
            currentStatus = existingLog.status;
          }

          scheduledIntakes.add(_ScheduledIntake(
            medication: med,
            scheduledTimeOfDay: time,
            scheduledTimestamp: scheduledTimestamp,
            logEntry: actualLogEntry,
            status: currentStatus,
          ));
        } catch (e) {
          debugPrint("Error parsing time for medication ${med.name}: $timeStr, Error: $e");
        }
      }
    }
    scheduledIntakes.sort((a, b) => a.scheduledTimestamp.compareTo(b.scheduledTimestamp));
    return scheduledIntakes;
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat timeFormat = DateFormat.Hm();
    final DateFormat dateFormat = DateFormat('yyyy年M月d日 (E)', 'ja_JP');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('${dateFormat.format(_selectedDate)}のお薬'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: '日付を選択',
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: '登録済みお薬一覧',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AllMedicationsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'ココロンに相談',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const EmpatheticChatScreen()));
            },
          ),
        ],
      ),
      body: _userId == null
          ? const Center(child: Text('ユーザー情報を取得できませんでした。'))
          : StreamBuilder<List<Medication>>(
              stream: _firestoreService.getMedicationsStream(_userId!),
              builder: (context, medSnapshot) {
                if (medSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (medSnapshot.hasError) {
                  return Center(child: Text('お薬リストの読込エラー: ${medSnapshot.error}'));
                }
                if (!medSnapshot.hasData || medSnapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.medication_outlined,
                              size: 64,
                              color: AppTheme.primaryColor.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'お薬が登録されていません',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '下のボタンからお薬を追加して\n服薬管理を始めましょう',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondaryColor,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Icon(
                            Icons.arrow_downward,
                            size: 32,
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allMedications = medSnapshot.data!;

                return StreamBuilder<List<MedicationLog>>(
                  stream: _firestoreService.getMedicationLogsStream(_userId!, date: _selectedDate),
                  builder: (context, logSnapshot) {
                    if (logSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (logSnapshot.hasError) {
                      return Center(child: Text('服用記録の読込エラー: ${logSnapshot.error}'));
                    }

                    final todayLogs = logSnapshot.data ?? [];
                    final scheduledIntakes = _prepareScheduledIntakes(allMedications, todayLogs);

                    if (scheduledIntakes.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.event_available,
                                  size: 64,
                                  color: AppTheme.secondaryColor.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '今日のお薬はありません',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                dateFormat.format(_selectedDate),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: scheduledIntakes.length,
                      itemBuilder: (context, index) {
                        final intake = scheduledIntakes[index];
                        IconData statusIcon;
                        Color statusColor;
                        String statusText = medicationIntakeStatusToString(intake.status);

                        switch (intake.status) {
                          case MedicationIntakeStatus.taken:
                            statusIcon = Icons.check_circle;
                            statusColor = Colors.green;
                            break;
                          case MedicationIntakeStatus.skipped:
                            statusIcon = Icons.cancel;
                            statusColor = Colors.orange;
                            break;
                          case MedicationIntakeStatus.missed: // You might need logic to set this, e.g., if time passed and still pending
                            statusIcon = Icons.error;
                            statusColor = Colors.red;
                            break;
                          case MedicationIntakeStatus.pending:
                          default:
                            statusIcon = Icons.radio_button_unchecked;
                            statusColor = Colors.grey;
                            break;
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            side: BorderSide(
                              color: AppTheme.textTertiaryColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        intake.medication.name,
                                        style: TextStyle(
                                          fontSize: 18, 
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(statusIcon, color: statusColor, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            statusText, 
                                            style: TextStyle(
                                              color: statusColor, 
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.schedule, size: 16, color: AppTheme.textSecondaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      timeFormat.format(intake.scheduledTimestamp.toDate()),
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.medical_services, size: 16, color: AppTheme.textSecondaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${intake.medication.dosage} (${intake.medication.form})',
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                if (intake.logEntry?.actualIntakeTime != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check, size: 14, color: AppTheme.textTertiaryColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          '記録時刻: ${timeFormat.format(intake.logEntry!.actualIntakeTime!.toDate())}', 
                                          style: TextStyle(
                                            fontSize: 12, 
                                            color: AppTheme.textTertiaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                if (intake.status == MedicationIntakeStatus.pending || intake.status == MedicationIntakeStatus.missed)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: const Text('服用した'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.successColor,
                                          side: BorderSide(color: AppTheme.successColor),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () => _logMedicationIntake(intake, MedicationIntakeStatus.taken),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        icon: const Icon(Icons.highlight_off),
                                        label: const Text('スキップ'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.warningColor,
                                        ),
                                        onPressed: () => _logMedicationIntake(intake, MedicationIntakeStatus.skipped),
                                      ),
                                    ],
                                  )
                                else 
                                  Row(
                                     mainAxisAlignment: MainAxisAlignment.end,
                                     children: [
                                       TextButton.icon(
                                        icon: const Icon(Icons.undo),
                                        label: const Text('取り消す'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.textSecondaryColor,
                                        ),
                                        onPressed: () => _logMedicationIntake(intake, MedicationIntakeStatus.pending),
                                      ),
                                     ]
                                  )
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MedicationAddEditScreen()));
          },
          tooltip: 'お薬を管理・追加',
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_circle_outline, size: 28),
          label: const Text(
            'お薬を追加',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// This screen is now for managing the master list of medications, not the daily schedule.
class AllMedicationsScreen extends StatelessWidget {
  const AllMedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('登録済みお薬一覧'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: userId == null
          ? const Center(child: Text('ユーザー情報を取得できませんでした。'))
          : StreamBuilder<List<Medication>>(
              stream: firestoreService.getMedicationsStream(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('エラー: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('登録されているお薬はありません。'));
                }
                final medications = snapshot.data!;
                return ListView.builder(
                  itemCount: medications.length,
                  itemBuilder: (context, index) {
                    final med = medications[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppTheme.textTertiaryColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          med.name, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${med.form} - ${med.dosage} (${med.frequency})',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        trailing: Icon(
                          med.reminderEnabled ? Icons.notifications_active : Icons.notifications_off, 
                          color: med.reminderEnabled ? AppTheme.primaryColor : AppTheme.textTertiaryColor,
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => MedicationAddEditScreen(medication: med)));
                        },
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MedicationAddEditScreen()));
          },
          tooltip: 'お薬を追加',
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_circle_outline, size: 28),
          label: const Text(
            '新しいお薬を追加',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
