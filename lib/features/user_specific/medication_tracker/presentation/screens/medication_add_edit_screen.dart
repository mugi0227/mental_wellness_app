import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mental_wellness_app/models/medication_model.dart';
import 'package:mental_wellness_app/services/firestore_service.dart';
import 'package:mental_wellness_app/services/local_notification_service.dart'; 
import 'package:intl/intl.dart'; 

class MedicationAddEditScreen extends StatefulWidget {
  final Medication? medication; 

  const MedicationAddEditScreen({super.key, this.medication});

  @override
  State<MedicationAddEditScreen> createState() => _MedicationAddEditScreenState();
}

class _MedicationAddEditScreenState extends State<MedicationAddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final LocalNotificationService _localNotificationService = LocalNotificationService(); 
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _formController; // Added form controller
  late TextEditingController _notesController;

  String _selectedFrequency = 'Daily'; 
  List<TimeOfDay> _selectedTimes = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _reminderEnabled = true;
  bool _isLoading = false;

  final List<String> _frequencyOptions = ['Daily', 'Twice a day', 'Three times a day', 'As needed', 'Custom'];
  final List<String> _formOptions = ['Tablet', 'Capsule', 'Liquid', 'Injection', 'Cream', 'Other']; // Added form options

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medication?.name ?? '');
    _dosageController = TextEditingController(text: widget.medication?.dosage ?? '');
    _formController = TextEditingController(text: widget.medication?.form ?? _formOptions.first); // Initialize form controller
    _notesController = TextEditingController(text: widget.medication?.notes ?? '');
    _selectedFrequency = widget.medication?.frequency ?? 'Daily';
    _reminderEnabled = widget.medication?.reminderEnabled ?? true;
    _startDate = widget.medication?.startDate?.toDate();
    _endDate = widget.medication?.endDate?.toDate();

    if (widget.medication?.times != null) {
      _selectedTimes = widget.medication!.times.map((timeStr) {
        try {
          final parts = timeStr.split(':');
          return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        } catch (e) {
          return TimeOfDay.now(); 
        }
      }).toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _formController.dispose(); // Dispose form controller
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(BuildContext context, {int? index}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: index != null && index < _selectedTimes.length ? _selectedTimes[index] : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (index != null && index < _selectedTimes.length) {
          _selectedTimes[index] = picked;
        } else {
          _selectedTimes.add(picked);
          _selectedTimes.sort((a, b) { 
            if (a.hour != b.hour) return a.hour.compareTo(b.hour);
            return a.minute.compareTo(b.minute);
          });
        }
      });
    }
  }

  void _removeTime(int index) {
    setState(() {
      _selectedTimes.removeAt(index);
    });
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    final format = DateFormat.jm(); 
    return format.format(dt);
  }
  
  String _formatTimeOfDayForStorage(TimeOfDay tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate() || _userId == null) {
      return;
    }
    if (_selectedFrequency != 'As needed' && _selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('服用時間を少なくとも1つは設定してください。')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final medicationData = Medication(
      id: widget.medication?.id,
      userId: _userId!,
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      form: _formController.text.trim(), // Save form
      frequency: _selectedFrequency,
      times: _selectedTimes.map(_formatTimeOfDayForStorage).toList(),
      startDate: _startDate != null ? Timestamp.fromDate(_startDate!) : null, // Save startDate
      endDate: _endDate != null ? Timestamp.fromDate(_endDate!) : null, // Save endDate
      reminderEnabled: _reminderEnabled,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: widget.medication?.createdAt ?? Timestamp.now(),
      updatedAt: widget.medication != null ? Timestamp.now() : null,
    );

    try {
      String medicationIdToUse = widget.medication?.id ?? '';

      if (widget.medication == null) {
        final docRef = await _firestoreService.addMedication(medicationData);
        medicationIdToUse = docRef.id; 
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('お薬が追加されました。')));
      } else {
        if(widget.medication!.id != null && widget.medication!.times.isNotEmpty){
            await _localNotificationService.cancelAllRemindersForMedication(widget.medication!.id!, widget.medication!.times.length);
        }
        await _firestoreService.updateMedication(medicationData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('お薬情報が更新されました。')));
      }

      if (_reminderEnabled && medicationIdToUse.isNotEmpty && medicationData.times.isNotEmpty) {
        final currentMedicationDetails = medicationData.copyWith(id: medicationIdToUse);
        await _localNotificationService.scheduleMedicationReminder(currentMedicationDetails);
      } else if (!_reminderEnabled && medicationIdToUse.isNotEmpty && widget.medication != null && widget.medication!.times.isNotEmpty) {
         await _localNotificationService.cancelAllRemindersForMedication(medicationIdToUse, widget.medication!.times.length);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが���生しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medication == null ? 'お薬を追加' : 'お薬を編集'),
        actions: [
          if (widget.medication != null)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '削除',
              onPressed: _isLoading ? null : () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('確認'),
                    content: const Text('このお薬を削除しますか？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('削除')),
                    ],
                  ),
                );
                if (confirm == true && _userId != null && widget.medication!.id != null) {
                  setState(() => _isLoading = true);
                  try {
                    if(widget.medication!.id != null && widget.medication!.times.isNotEmpty){
                        await _localNotificationService.cancelAllRemindersForMedication(widget.medication!.id!, widget.medication!.times.length);
                    }
                    await _firestoreService.deleteMedication(_userId!, widget.medication!.id!);
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('お薬が削除されました。')));
                      navigator.pop(); 
                    }
                  } catch (e) {
                     if (mounted) {
                       scaffoldMessenger.showSnackBar(SnackBar(content: Text('削除エラー: $e')));
                     }
                  } finally {
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: _userId == null
          ? const Center(child: Text('ユーザー情報が必要です。'))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'お薬の名前'),
                      validator: (value) => value == null || value.isEmpty ? 'お薬の名前を入力してください。' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(labelText: '用法・用量 (例: 1錠, 10mg)'),
                      validator: (value) => value == null || value.isEmpty ? '用法・用量を入力してください。' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                                            decoration: const InputDecoration(labelText: '剤形'),
                      value: _formOptions.contains(_formController.text) ? _formController.text : _formOptions.first,
                      items: _formOptions.map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _formController.text = newValue;
                          });
                        }
                      },
                       validator: (value) => value == null || value.isEmpty ? '剤形を選択してください。' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedFrequency,
                      decoration: const InputDecoration(labelText: '頻度'),
                      items: _frequencyOptions.map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedFrequency = newValue!;
                          if (_selectedFrequency == 'As needed') {
                            _selectedTimes.clear(); 
                          }
                        });
                      },
                    ),
                    if (_selectedFrequency != 'As needed') ...[
                      const SizedBox(height: 16),
                      Text('服用時間:', style: Theme.of(context).textTheme.titleSmall),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _selectedTimes.asMap().entries.map((entry) {
                          int idx = entry.key;
                          TimeOfDay tod = entry.value;
                          return Chip(
                            label: Text(_formatTimeOfDay(tod)),
                            onDeleted: () => _removeTime(idx),
                            deleteIcon: const Icon(Icons.close, size: 18),
                          );
                        }).toList(),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_alarm),
                        label: const Text('時間を追加'),
                        onPressed: () => _pickTime(context),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(_startDate == null ? '��始日 (任意)' : '開始日: ${DateFormat('yyyy/MM/dd').format(_startDate!)}'),
                        ),
                        TextButton(
                          onPressed: () => _pickDate(context, true),
                          child: Text(_startDate == null ? '選択' : '変更'),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(_endDate == null ? '終了日 (任意)' : '終了日: ${DateFormat('yyyy/MM/dd').format(_endDate!)}'),
                        ),
                        TextButton(
                          onPressed: () => _pickDate(context, false),
                          child: Text(_endDate == null ? '選択' : '変更'),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('リマインダー'),
                      value: _reminderEnabled,
                      onChanged: (bool value) => setState(() => _reminderEnabled = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'メモ (任意)', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveMedication,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                          : const Text('保存'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
