import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: OGMessengerApp(),
    ),
  );
}

class OGMessengerApp extends StatelessWidget {
  const OGMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OG Messenger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('OG Messenger - Coming Soon'),
        ),
      ),
    );
  }
}

