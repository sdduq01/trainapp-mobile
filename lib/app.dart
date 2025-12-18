import 'package:flutter/material.dart';

class TrainApp extends StatelessWidget {
  const TrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'TrainApp 🚀',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
