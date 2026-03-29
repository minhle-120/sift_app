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
          
          _buildControlCard(
            context,
            title: 'Specialized Capabilities',
            icon: Icons.extension_rounded,
            isEnabled: settings.aiMode == AiMode.research,
            child: Column(
              children: [
                ...plugins.asMap().entries.map((entry) {
                  final index = entry.key;
                  final plugin = entry.value;
                  final mode = settings.pluginModes[plugin.id] ?? PluginMode.auto;
                  
                  return Column(
                    children: [
                      _buildPluginRow(context, plugin, mode, settingsNotifier, theme),
                      if (index < plugins.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            thickness: 0.5,
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
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
              : 'Exhaustive search and synthesis. Automatically coordinates specialized tools like Graph and Coder.',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPluginRow(
    BuildContext context, 
    AgentPlugin plugin, 
    PluginMode currentMode, 
    SettingsController notifier,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            plugin.icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            plugin.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _buildPluginToggles(plugin, currentMode, notifier, theme),
      ],
    );
  }

  Widget _buildPluginToggles(AgentPlugin plugin, PluginMode currentMode, SettingsController notifier, ThemeData theme) {
    return SizedBox(
      height: 32,
      child: SegmentedButton<PluginMode>(
        segments: const [
          ButtonSegment(
            value: PluginMode.auto, 
            label: Text('Auto', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment(
            value: PluginMode.on, 
            label: Text('On', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment(
            value: PluginMode.off, 
            label: Text('Off', style: TextStyle(fontSize: 12)),
          ),
        ],
        selected: {currentMode},
        onSelectionChanged: (value) => notifier.setPluginMode(plugin.id, value.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return theme.colorScheme.primaryContainer;
            }
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return theme.colorScheme.onPrimaryContainer;
            }
            return theme.colorScheme.onSurfaceVariant;
          }),
        ),
      ),
    );
  }
}
