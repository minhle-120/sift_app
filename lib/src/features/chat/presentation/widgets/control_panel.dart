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
            subtitle: 'Fine-tune how your AI generates content and graphs.',
          ),
          const SizedBox(height: 24),

          _buildAiModeSelector(context, settings, settingsNotifier),

          const SizedBox(height: 32),
          
          _buildControlCard(
            context,
            title: 'Graph Generator',
            icon: Icons.hub_rounded,
            description: _getGraphGeneratorDescription(settings.graphGeneratorMode),
            isEnabled: settings.aiMode == AiMode.research,
            child: _buildGraphGeneratorToggles(settings, settingsNotifier, theme),
          ),
          
          const SizedBox(height: 24),
          
          _buildControlCard(
            context,
            title: 'Code',
            icon: Icons.terminal_rounded,
            description: _getCoderDescription(settings.coderMode),
            isEnabled: settings.aiMode == AiMode.research,
            child: _buildCoderToggles(settings, settingsNotifier, theme),
          ),
          
          const SizedBox(height: 24),

          _buildControlCard(
            context,
            title: 'Flashcard',
            icon: Icons.psychology_rounded,
            description: _getFlashcardDescription(settings.flashcardMode),
            isEnabled: settings.aiMode == AiMode.research,
            child: _buildFlashcardToggles(settings, settingsNotifier, theme),
          ),
          
          const SizedBox(height: 24),

          _buildControlCard(
            context,
            title: 'Canvas',
            icon: Icons.auto_awesome_mosaic_rounded,
            description: _getInteractiveCanvasDescription(settings.interactiveCanvasMode),
            isEnabled: settings.aiMode == AiMode.research,
            child: _buildInteractiveCanvasToggles(settings, settingsNotifier, theme),
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
          subtitle: settings.isMobileInternal 
              ? 'Pure LLM knowledge base (Disabled on Mobile Internal AI).'
              : 'Pure LLM knowledge base. Bypasses your local documents entirely. Best for creative unconstrained ideation.',
          icon: Icons.lightbulb_outline_rounded,
          value: AiMode.brainstorm,
          groupValue: settings.aiMode,
          onChanged: settings.isMobileInternal ? null : (v) => notifier.updateAiMode(v!),
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

  Widget _buildGraphGeneratorToggles(SettingsState settings, SettingsController notifier, ThemeData theme) {
    return SegmentedButton<GraphGeneratorMode>(
      segments: const [
        ButtonSegment(
          value: GraphGeneratorMode.auto,
          label: Text('Auto'),
        ),
        ButtonSegment(
          value: GraphGeneratorMode.on,
          label: Text('On'),
        ),
        ButtonSegment(
          value: GraphGeneratorMode.off,
          label: Text('Off'),
        ),
      ],
      selected: {settings.graphGeneratorMode},
      onSelectionChanged: (value) => notifier.updateGraphGeneratorMode(value.first),
      showSelectedIcon: false,
    );
  }

  Widget _buildCoderToggles(SettingsState settings, SettingsController notifier, ThemeData theme) {
    return SegmentedButton<CoderMode>(
      segments: const [
        ButtonSegment(
          value: CoderMode.auto,
          label: Text('Auto'),
        ),
        ButtonSegment(
          value: CoderMode.on,
          label: Text('On'),
        ),
        ButtonSegment(
          value: CoderMode.off,
          label: Text('Off'),
        ),
      ],
      selected: {settings.coderMode},
      onSelectionChanged: (value) => notifier.updateCoderMode(value.first),
      showSelectedIcon: false,
    );
  }

  Widget _buildFlashcardToggles(SettingsState settings, SettingsController notifier, ThemeData theme) {
    return SegmentedButton<FlashcardMode>(
      segments: const [
        ButtonSegment(
          value: FlashcardMode.auto,
          label: Text('Auto'),
        ),
        ButtonSegment(
          value: FlashcardMode.on,
          label: Text('On'),
        ),
        ButtonSegment(
          value: FlashcardMode.off,
          label: Text('Off'),
        ),
      ],
      selected: {settings.flashcardMode},
      onSelectionChanged: (value) => notifier.updateFlashcardMode(value.first),
      showSelectedIcon: false,
    );
  }

  Widget _buildInteractiveCanvasToggles(SettingsState settings, SettingsController notifier, ThemeData theme) {
    return SegmentedButton<InteractiveCanvasMode>(
      segments: const [
        ButtonSegment(
          value: InteractiveCanvasMode.auto,
          label: Text('Auto'),
        ),
        ButtonSegment(
          value: InteractiveCanvasMode.on,
          label: Text('On'),
        ),
        ButtonSegment(
          value: InteractiveCanvasMode.off,
          label: Text('Off'),
        ),
      ],
      selected: {settings.interactiveCanvasMode},
      onSelectionChanged: (value) => notifier.updateInteractiveCanvasMode(value.first),
      showSelectedIcon: false,
    );
  }

  String _getGraphGeneratorDescription(GraphGeneratorMode mode) {
    switch (mode) {
      case GraphGeneratorMode.auto:
        return 'AI smartly chooses when to generate graphs or diagrams based on your request context.';
      case GraphGeneratorMode.on:
        return 'AI will attempt to generate graphs whenever possible, even for simpler requests.';
      case GraphGeneratorMode.off:
        return 'Disables graph generation entirely for a faster, text-only conversational experience.';
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

  String _getFlashcardDescription(FlashcardMode mode) {
    switch (mode) {
      case FlashcardMode.auto:
        return 'AI creates flashcard decks when it detects a learning objective or complex topic.';
      case FlashcardMode.on:
        return 'AI treats every research turn as a flashcard session, distilling information into atomic cards.';
      case FlashcardMode.off:
        return 'Disables flashcard generation entirely. Useful for purely data-driven research tasks.';
    }
  }

  String _getInteractiveCanvasDescription(InteractiveCanvasMode mode) {
    switch (mode) {
      case InteractiveCanvasMode.auto:
        return 'AI creates highly interactive HTML/SVG components when data complexity warrants custom visualization.';
      case InteractiveCanvasMode.on:
        return 'AI prioritizes building interactive canvases and structured reports for every research task.';
      case InteractiveCanvasMode.off:
        return 'Disables interactive canvas generation for a strictly text and standard graph experience.';
    }
  }
}
