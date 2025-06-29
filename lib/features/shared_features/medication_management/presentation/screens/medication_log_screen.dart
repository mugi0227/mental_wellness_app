import 'package:flutter/material.dart';

class MedicationLogScreen extends StatelessWidget {
  const MedicationLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お薬手帳'),
        backgroundColor: Colors.green[100], // 落ち着いた緑色
      ),
      body: const Center(
        child: Text('お薬手帳画面'),
      ),
    );
  }
}
