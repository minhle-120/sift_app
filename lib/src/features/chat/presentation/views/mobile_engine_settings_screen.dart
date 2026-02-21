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
            onChanged: (val) => ref.read(settingsProvider.notifier).updateMobileUseGpu(val),
            secondary: const Icon(Icons.bolt_rounded, color: Colors.orange),
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
    required String label,
    required String path,
    required bool isInitialized,
    required VoidCallback onPick,
    required VoidCallback onInitialize,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_present_rounded, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelMedium),
                      Text(
                        path.isEmpty ? 'No model selected' : p.basename(path),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: path.isEmpty ? null : 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onPick,
                  icon: const Icon(Icons.folder_open_rounded),
                  tooltip: 'Select Model',
                ),
              ],
            ),
            if (path.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isInitialized ? Icons.verified_user_rounded : Icons.update_disabled_rounded,
                        color: isInitialized ? Colors.green : theme.hintColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isInitialized ? 'Loaded & Ready' : 'Uninitialized',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isInitialized ? Colors.green : theme.hintColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: onInitialize,
                    icon: Icon(isInitialized ? Icons.refresh_rounded : Icons.play_arrow_rounded, size: 18),
                    label: Text(isInitialized ? 'Re-initialize' : 'Initialize'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
