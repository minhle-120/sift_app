import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/settings_controller.dart';
import '../../../../../core/models/ai_models.dart';

class ControlPanel extends ConsumerWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            title: 'AI Control Center',
            subtitle: 'Fine-tune how your AI generates content and visualizations.',
          ),
          const SizedBox(height: 32),
          
          _buildControlCard(
            context,
            title: 'AI Visualizer',
            icon: Icons.auto_awesome_mosaic_rounded,
            description: _getVisualizerDescription(settings.visualizerMode),
            child: _buildVisualizerToggles(settings, settingsNotifier, theme),
          ),
          
          const SizedBox(height: 24),
          
          _buildControlCard(
            context,
            title: 'AI Coder',
            icon: Icons.terminal_rounded,
            description: _getCoderDescription(settings.coderMode),
            child: _buildCoderToggles(settings, settingsNotifier, theme),
          ),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, {required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildControlCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String description,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerToggles(SettingsState settings, SettingsController notifier, ThemeData theme) {
    return SegmentedButton<VisualizerMode>(
      segments: const [
        ButtonSegment(
          value: VisualizerMode.auto,
          label: Text('Auto'),
          icon: Icon(Icons.auto_awesome_outlined, size: 16),
        ),
        ButtonSegment(
          value: VisualizerMode.on,
          label: Text('Always On'),
          icon: Icon(Icons.visibility_outlined, size: 16),
        ),
        ButtonSegment(
          value: VisualizerMode.off,
          label: Text('Off'),
          icon: Icon(Icons.visibility_off_outlined, size: 16),
        ),
      ],
      selected: {settings.visualizerMode},
      onSelectionChanged: (value) => notifier.updateVisualizerMode(value.first),
      showSelectedIcon: false,
    );
  }

  Widget _buildCoderToggles(SettingsState settings, SettingsController notifier, ThemeData theme) {
    return SegmentedButton<CoderMode>(
      segments: const [
        ButtonSegment(
          value: CoderMode.auto,
          label: Text('Auto'),
          icon: Icon(Icons.code_rounded, size: 16),
        ),
        ButtonSegment(
          value: CoderMode.on,
          label: Text('Always On'),
          icon: Icon(Icons.terminal_rounded, size: 16),
        ),
        ButtonSegment(
          value: CoderMode.off,
          label: Text('Off'),
          icon: Icon(Icons.code_off_rounded, size: 16),
        ),
      ],
      selected: {settings.coderMode},
      onSelectionChanged: (value) => notifier.updateCoderMode(value.first),
      showSelectedIcon: false,
    );
  }

  String _getVisualizerDescription(VisualizerMode mode) {
    switch (mode) {
      case VisualizerMode.auto:
        return 'AI smartly chooses when to generate charts or diagrams based on your request context.';
      case VisualizerMode.on:
        return 'AI will attempt to visualize data points and structures whenever possible, even for simpler requests.';
      case VisualizerMode.off:
        return 'Disables code-based visualizations entirely for a faster, text-only conversational experience.';
    }
  }

  String _getCoderDescription(CoderMode mode) {
    switch (mode) {
      case CoderMode.auto:
        return 'AI provides code snippets and logic when technically relevant to the conversation.';
      case CoderMode.on:
        return 'AI prioritizes technical implementation, optimization, and logical structures in every response.';
      case CoderMode.off:
        return 'Disables rich code generation, focusing the AI on more natural, conversational interactions.';
    }
  }
}
