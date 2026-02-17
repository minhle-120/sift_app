import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/sift_theme.dart';
import 'src/features/chat/presentation/views/chat_screen.dart';
import 'src/features/chat/presentation/controllers/settings_controller.dart';
import 'src/features/setup/presentation/views/setup_screen.dart';

/// Global container reference so signal handlers can reach providers.
late ProviderContainer _container;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  _container = ProviderContainer();

  // ── OS signal handlers (Ctrl-C, kill, systemctl stop, etc.) ──
  // These fire BEFORE the process exits, giving us a chance to clean up.
  if (!Platform.isWindows) {
    ProcessSignal.sigint.watch().listen((_) => _cleanup());
    ProcessSignal.sigterm.watch().listen((_) => _cleanup());
  }

  runApp(
    UncontrolledProviderScope(
      container: _container,
      child: const SiftApp(),
    ),
  );
}

Future<void> _cleanup() async {
  final downloader = _container.read(settingsProvider.notifier).downloader;
  await downloader.stopServer();
  exit(0);
}

class SiftApp extends StatefulWidget {
  const SiftApp({super.key});

  @override
  State<SiftApp> createState() => _SiftAppState();
}

class _SiftAppState extends State<SiftApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        // Graceful window close (X button, Alt-F4, etc.)
        await _cleanup();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

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
