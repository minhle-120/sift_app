import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/sift_theme.dart';
import 'src/features/chat/presentation/views/chat_screen.dart';
import 'src/features/chat/presentation/controllers/settings_controller.dart';
import 'src/features/setup/presentation/views/setup_screen.dart';

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
      home: const _AppGate(),
    );
  }
}

/// Gates the app behind the first-time setup screen.
class _AppGate extends ConsumerWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // Wait for SharedPreferences to load before deciding
    if (!settings.isSettingsLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return settings.isSetupComplete ? const ChatScreen() : const SetupScreen();
  }
}
