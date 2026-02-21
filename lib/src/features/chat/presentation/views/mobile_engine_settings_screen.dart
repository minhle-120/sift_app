import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../controllers/settings_controller.dart';

class MobileEngineSettingsScreen extends ConsumerWidget {
  const MobileEngineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile AI Engine'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (settings.mobileImportProgress > 0 && settings.mobileImportProgress < 1.0) ...[
            _buildImportProgressBar(theme, settings.mobileImportProgress),
            const SizedBox(height: 16),
          ],
          _buildStatusOverview(context, theme, settings),
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Generation Model (LiteRT)'),
          _buildModelPicker(
            theme,
            ref: ref,
            label: 'LiteRT Model (.task)',
            path: settings.mobileGenModelPath,
            isInitialized: settings.isMobileEngineInitialized,
            onPick: () => ref.read(settingsProvider.notifier).pickMobileGenModel(),
            onInitialize: () => ref.read(settingsProvider.notifier).initializeMobileEngine(),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Embedding Model (MediaPipe)'),
          _buildModelPicker(
            theme,
            ref: ref,
            label: 'Embedding Model (.tflite)',
            path: settings.mobileEmbedModelPath,
            isInitialized: settings.isMobileEmbedderInitialized,
            onPick: () => ref.read(settingsProvider.notifier).pickMobileEmbedModel(),
            onInitialize: () => ref.read(settingsProvider.notifier).initializeMobileEmbedder(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Row(
              children: [
                Icon(
                  settings.mobileTokenizerPath.isEmpty ? Icons.auto_awesome : Icons.fact_check,
                  size: 14,
                  color: settings.mobileTokenizerPath.isEmpty ? Colors.amber : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    settings.mobileTokenizerPath.isEmpty 
                        ? 'Tokenizer: Auto-detect (sentencepiece.model)' 
                        : 'Tokenizer: ${p.basename(settings.mobileTokenizerPath)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: settings.mobileTokenizerPath.isEmpty ? theme.hintColor : Colors.blue,
                      fontStyle: settings.mobileTokenizerPath.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: settings.mobileTokenizerPath.isEmpty 
                      ? () => ref.read(settingsProvider.notifier).pickMobileTokenizer()
                      : () => ref.read(settingsProvider.notifier).clearMobileTokenizer(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    settings.mobileTokenizerPath.isEmpty ? 'Manual Override' : 'Clear Override', 
                    style: TextStyle(fontSize: 10, color: settings.mobileTokenizerPath.isEmpty ? null : Colors.red),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Hardware Settings'),
          SwitchListTile(
            title: const Text('Use GPU Acceleration'),
            subtitle: const Text('Enable mobile GPU for faster inference'),
            value: settings.mobileUseGpu,
            onChanged: settings.isInitializingMobileEngine 
              ? null 
              : (val) => ref.read(settingsProvider.notifier).updateMobileUseGpu(val),
            secondary: Icon(
              Icons.bolt_rounded, 
              color: settings.isInitializingMobileEngine ? theme.disabledColor : Colors.orange,
            ),
          ),
          if (settings.mobileEngineError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      settings.mobileEngineError!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImportProgressBar(ThemeData theme, double progress) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Importing Model...',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverview(BuildContext context, ThemeData theme, SettingsState settings) {
    final genReady = settings.isMobileEngineInitialized;
    final embedReady = settings.isMobileEmbedderInitialized;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  (genReady && embedReady) ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: (genReady && embedReady) ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  (genReady && embedReady) ? 'Engine Ready' : 'System Not Fully Initialized',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSimpleStat(theme, 'Generation', genReady ? 'Ready' : 'Pending'),
                _buildSimpleStat(theme, 'Embedding', embedReady ? 'Ready' : 'Pending'),
                _buildSimpleStat(theme, 'Acceleration', settings.mobileUseGpu ? 'GPU' : 'CPU'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleStat(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _buildModelPicker(
    ThemeData theme, {
    required WidgetRef ref,
    required String label,
    required String path,
    required bool isInitialized,
    required VoidCallback onPick,
    required VoidCallback onInitialize,
  }) {
    final bool isGenModel = label.contains('LiteRT');
    final bool isInitializing = isGenModel && ref.watch(settingsProvider).isInitializingMobileEngine;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isInitializing) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  path.isEmpty ? 'Not selected' : p.basename(path),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: path.isEmpty ? theme.hintColor : theme.colorScheme.onSurface,
                    fontStyle: path.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (path.isEmpty || !isInitialized)
                ElevatedButton(
                  onPressed: isInitializing ? null : (path.isEmpty ? onPick : onInitialize),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(isInitializing 
                    ? 'Wait...' 
                    : (path.isEmpty ? 'Select' : 'Initialize')),
                )
              else
                Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 24),
            ],
          ),
          if (path.isNotEmpty && isInitialized) ...[
             const SizedBox(height: 8),
             Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isInitializing ? null : onInitialize,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Re-initialize', style: TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
