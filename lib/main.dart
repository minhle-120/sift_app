import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syntax_highlight/syntax_highlight.dart';
import 'core/theme/sift_theme.dart';
import 'src/features/chat/presentation/views/chat_screen.dart';
import 'src/features/chat/presentation/controllers/settings_controller.dart';
import 'src/features/setup/presentation/views/setup_screen.dart';

/// Global container reference so signal handlers can reach providers.
late ProviderContainer _container;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the highlighter with common languages.
  await Highlighter.initialize([
    'dart', 'yaml', 'sql', 'json', 'python', 'javascript', 'typescript', 'html', 'css', 'go', 'java', 'kotlin', 'rust', 'swift'
  ]);
  
  SiftTheme.lightCodeTheme = await HighlighterTheme.loadLightTheme();
  SiftTheme.darkCodeTheme = await HighlighterTheme.loadDarkTheme();

  _container = ProviderContainer();

  // ── OS signal handlers (Ctrl-C, kill, systemctl stop, etc.) ──
  // These fire BEFORE the process exits, giving us a chance to clean up.
  if (!Platform.isWindows && !Platform.isAndroid && !Platform.isIOS) {
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
      scrollBehavior: NoScrollbarBehavior(),
      home: const _AppGate(),
    );
  }
}

class NoScrollbarBehavior extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
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
