import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../chat/presentation/controllers/settings_controller.dart';
import '../../../chat/presentation/views/local_engine_settings_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  BackendType? _selectedType;
  final _urlController = TextEditingController(text: 'http://localhost:8080');

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Title
                Icon(
                  Icons.auto_awesome,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to Sift',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to connect to an AI backend.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.hintColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Option Cards
                _buildOptionCard(
                  theme: theme,
                  icon: Icons.cloud_outlined,
                  title: 'External Server',
                  description: 'Connect to a remote or self-hosted llama.cpp server via URL.',
                  type: BackendType.external,
                ),
                const SizedBox(height: 12),
                _buildOptionCard(
                  theme: theme,
                  icon: Icons.memory,
                  title: 'Internal (Bundled)',
                  description: 'Download and run llama.cpp locally. Everything stays on your device.',
                  type: BackendType.internal,
                ),

                const SizedBox(height: 32),

                // Conditional content based on selection
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildSelectionContent(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String description,
    required BackendType type,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected ? theme.colorScheme.primary : theme.hintColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionContent(ThemeData theme) {
    if (_selectedType == null) {
      return const SizedBox.shrink(key: ValueKey('empty'));
    }

    if (_selectedType == BackendType.external) {
      return Column(
        key: const ValueKey('external'),
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              border: OutlineInputBorder(),
              helperText: 'e.g. http://192.168.1.100:8080',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () async {
                final notifier = ref.read(settingsProvider.notifier);
                await notifier.updateBackendType(BackendType.external);
                await notifier.updateLlamaServerUrl(_urlController.text.trim());
                await notifier.completeSetup();
                // _AppGate will reactively switch to ChatScreen
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue'),
            ),
          ),
        ],
      );
    }

    // Internal
    return Column(
      key: const ValueKey('internal'),
      children: [
        Text(
          'Set up your local AI engine in the next screen.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: () async {
              final notifier = ref.read(settingsProvider.notifier);
              await notifier.updateBackendType(BackendType.internal);
              await notifier.completeSetup();
              if (mounted) {
                // completeSetup triggers _AppGate to show ChatScreen,
                // then push LocalEngineSettings on top so user can configure
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LocalEngineSettingsScreen()),
                );
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Set Up Local Engine'),
          ),
        ),
      ],
    );
  }
}
