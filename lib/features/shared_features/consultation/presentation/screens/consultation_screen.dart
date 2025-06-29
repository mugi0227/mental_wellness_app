import 'package:flutter/material.dart';

class ConsultationScreen extends StatelessWidget {
  const ConsultationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('相談'),
        backgroundColor: Colors.green[100], // 落ち着いた緑色
      ),
      body: const Center(
        child: Text('相談画面'),
      ),
    );
  }
}
