import 'package:flutter/material.dart';

void main() {
  runApp(const ShwapyApp());
}

class ShwapyApp extends StatelessWidget {
  const ShwapyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shwapy',
      home: Scaffold(
        appBar: AppBar(title: const Text('Shwapy')),
        body: const Center(
          child: Text('Shwapy mobile scaffold initialized'),
        ),
      ),
    );
  }
}
