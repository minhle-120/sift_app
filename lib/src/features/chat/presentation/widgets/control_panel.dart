import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/settings_controller.dart';
import '../../../../../core/models/ai_models.dart';
import '../../../../../core/plugins/plugins_provider.dart';
import '../../../../../core/plugins/agent_plugin.dart';

class ControlPanel extends ConsumerWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final plugins = ref.watch(pluginsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            title: 'AI Control Center',
            subtitle: 'Fine-tune how your AI generates content and graphs.',
          ),
          const SizedBox(height: 24),

          _buildAiModeSelector(context, settings, settingsNotifier),

          const SizedBox(height: 32),
          
          ...plugins.map((plugin) {
            final mode = settings.pluginModes[plugin.id] ?? PluginMode.auto;
            return Column(
              children: [
                _buildControlCard(
                  context,
                  title: plugin.name,
                  icon: plugin.icon,
                  description: _getModeDescription(plugin, mode),
                  isEnabled: settings.aiMode == AiMode.research,
                  child: _buildPluginToggles(plugin, mode, settingsNotifier, theme),
                ),
                const SizedBox(height: 24),
              ],
            );
          }),
          
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

  Widget _buildAiModeSelector(BuildContext context, SettingsState settings, SettingsController notifier) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModeOption(
          context,
          title: 'Research Mode',
          subtitle: settings.isMobileInternal 
              ? 'Exhaustive research is currently not supported for the internal Mobile AI engine.'
              : 'Exhaustive search and synthesis. Automatically coordinates specialized tools like Graph Generator and Coder.',
          icon: Icons.manage_search_rounded,
          value: AiMode.research,
          groupValue: settings.aiMode,
          onChanged: settings.isMobileInternal ? null : (v) => notifier.updateAiMode(v!),
          theme: theme,
        ),
        const SizedBox(height: 12),
        _buildModeOption(
          context,
          title: 'Lite Mode',
          subtitle: 'Direct and fast single-search RAG. Skips iterative reasoning and specialized tools.',
          icon: Icons.flash_on_rounded,
          value: AiMode.lite,
          groupValue: settings.aiMode,
          onChanged: (v) => notifier.updateAiMode(v!),
          theme: theme,
        ),
        const SizedBox(height: 12),
        _buildModeOption(
          context,
          title: 'Brainstorm Mode',
          subtitle: 'Pure LLM knowledge base. Bypasses your local documents entirely. Best for creative unconstrained ideation.',
          icon: Icons.lightbulb_outline_rounded,
          value: AiMode.brainstorm,
          groupValue: settings.aiMode,
          onChanged: (v) => notifier.updateAiMode(v!),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildModeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required AiMode value,
    required AiMode groupValue,
    required ValueChanged<AiMode?>? onChanged,
    required ThemeData theme,
  }) {
    final isSelected = value == groupValue;
    final isDisabled = onChanged == null;
    
    return InkWell(
      onTap: isDisabled ? null : () => onChanged(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDisabled 
                  ? theme.disabledColor
                  : (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDisabled 
                          ? theme.disabledColor
                          : (isSelected ? theme.colorScheme.primary : null),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? theme.colorScheme.primary 
                      : (isDisabled ? theme.disabledColor : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String description,
    required Widget child,
    bool isEnabled = true,
  }) {
    final theme = Theme.of(context);
    
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: Container(
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
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
        ),
      ),
    );
  }

  Widget _buildPluginToggles(AgentPlugin plugin, PluginMode currentMode, SettingsController notifier, ThemeData theme) {
    return SegmentedButton<PluginMode>(
      segments: const [
        ButtonSegment(value: PluginMode.auto, label: Text('Auto')),
        ButtonSegment(value: PluginMode.on, label: Text('On')),
        ButtonSegment(value: PluginMode.off, label: Text('Off')),
      ],
      selected: {currentMode},
      onSelectionChanged: (value) => notifier.setPluginMode(plugin.id, value.first),
      showSelectedIcon: false,
    );
  }

  String _getModeDescription(AgentPlugin plugin, PluginMode mode) {
    switch (mode) {
      case PluginMode.auto:
        return 'AI will automatically decide when to use the ${plugin.name} feature based on the context of your request.';
      case PluginMode.on:
        return 'AI will prioritize using the ${plugin.name} feature whenever possible.';
      case PluginMode.off:
        return 'The ${plugin.name} feature is completely disabled for this conversation.';
    }
  }
}
