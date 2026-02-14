import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/sift_theme.dart';
import 'src/features/chat/presentation/views/chat_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SiftApp(),
    ),
  );
}

class SiftApp extends StatelessWidget {
  const SiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sift',
      debugShowCheckedModeBanner: false,
      theme: SiftTheme.darkTheme,
      home: const ChatScreen(),
    );
  }
}
