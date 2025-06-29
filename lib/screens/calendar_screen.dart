import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mental_wellness_app/models/ai_diary_log_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:mental_wellness_app/features/user_specific/ai_diary_log/presentation/screens/diary_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late StreamSubscription<List<AiDiaryLog>> _moodLogsSubscription;
  Map<DateTime, List<AiDiaryLog>> _moodLogsByDay = {};
  List<AiDiaryLog> _selectedMoodLogs = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _moodLogsSubscription = _firestoreService.getAiDiaryLogsStream(currentUser.uid).listen((moodLogs) {
        final newLogsByDay = <DateTime, List<AiDiaryLog>>{};
        for (final log in moodLogs) {
          final day = DateTime.utc(log.timestamp.toDate().year, log.timestamp.toDate().month, log.timestamp.toDate().day);
          newLogsByDay.putIfAbsent(day, () => []).add(log);
        }
        setState(() {
          _moodLogsByDay = newLogsByDay;
          _selectedMoodLogs = _getMoodLogsForDay(_selectedDay!);
        });
      });
    }
  }

  @override
  void dispose() {
    _moodLogsSubscription.cancel();
    super.dispose();
  }

  List<AiDiaryLog> _getMoodLogsForDay(DateTime day) {
    // Normalize the input day to UTC to match the keys in _moodLogsByDay
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _moodLogsByDay[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedMoodLogs = _getMoodLogsForDay(selectedDay);
      });
    }
  }

  Color _getMoodColor(int moodLevel) {
    switch (moodLevel) {
      case 1: return Colors.red.shade300;
      case 2: return Colors.orange.shade300;
      case 3: return Colors.grey.shade400;
      case 4: return Colors.lightGreen.shade300;
      case 5: return Colors.green.shade300;
      default: return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ココロのカレンダー'),
      ),
      body: Column(
        children: [
          TableCalendar<AiDiaryLog>(
            locale: 'ja_JP', // Japanese locale for calendar
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: _getMoodLogsForDay,
            startingDayOfWeek: StartingDayOfWeek.sunday, // Or monday
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              markerDecoration: BoxDecoration(
                color: Colors.blue[400],
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.orange[200],
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, // Hides the format button (e.g., "2 weeks", "Month")
              titleCentered: true,
            ),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  // If multiple logs for a day, could show multiple markers or a summary
                  // For now, use the color of the first log's mood
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getMoodColor(events.first.selfReportedMoodScore),
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _selectedMoodLogs.isNotEmpty
                ? ListView.builder(
                    itemCount: _selectedMoodLogs.length,
                    itemBuilder: (context, index) {
                      final log = _selectedMoodLogs[index];
                      return Dismissible(
                        key: ValueKey(log.id),
                        background: Container(
                          color: Colors.red[700],
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: AlignmentDirectional.centerStart,
                          child: const Icon(
                            Icons.delete_sweep_outlined,
                            color: Colors.white,
                          ),
                        ),
                        secondaryBackground: Container(
                          color: Colors.red[700],
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: AlignmentDirectional.centerEnd,
                          child: const Icon(
                            Icons.delete_sweep_outlined,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('日記の削除'),
                                content: Text('この日記「${DateFormat('HH:mm').format(log.timestamp.toDate())}」を本当に削除しますか？この操作は取り消せません。'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text('削除', style: TextStyle(color: Colors.red[700])),
                                  ),
                                ],
                              );
                            },
                          );
                          return confirmed;
                        },
                        onDismissed: (direction) async {
                          final user = _auth.currentUser;
                          if (user != null && log.id != null) {
                            try {
                              await _firestoreService.deleteAiDiaryLog(user.uid, log.id!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('「${DateFormat('HH:mm').format(log.timestamp.toDate())}」の日記を削除しました。')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('日記の削除中にエラーが発生しました: $e')),
                              );
                            }
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getMoodColor(log.selfReportedMoodScore),
                              child: Text(log.selfReportedMoodScore.toString(), style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(DateFormat('HH:mm').format(log.timestamp.toDate())),
                            subtitle: Text(log.diaryText.isNotEmpty ? log.diaryText : '日記はありません', maxLines: 2, overflow: TextOverflow.ellipsis,),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DiaryDetailScreen(diaryLog: log),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text('選択した日付に記録はありません。'),
                  ),
          ),
        ],
      ),
    );
  }
}
