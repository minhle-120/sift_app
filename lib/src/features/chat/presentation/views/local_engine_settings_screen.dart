import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../controllers/settings_controller.dart';

class LocalEngineSettingsScreen extends ConsumerWidget {
  const LocalEngineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local AI Executive'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatusCard(context, theme, ref, settings),
          const SizedBox(height: 16),
          _buildHardwareSection(context, ref, settings),
          const SizedBox(height: 24),
          _buildEngineSelectionSection(context, theme, ref, settings),
          const SizedBox(height: 24),
          _buildModelLibrarySection(context, theme, ref, settings),
          const SizedBox(height: 16),
          _buildModelBundleCard(context, ref, settings),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, ThemeData theme, WidgetRef ref, SettingsState settings) {
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
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey, // Ready/Idle status
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Engine: Ready',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _showLogsModal(context, settings, ref),
                  icon: const Icon(Icons.terminal, size: 18),
                  label: const Text('Logs'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    // Start Engine Logic
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSimpleStat(theme, 'Backend', 'Vulkan'),
                _buildSimpleStat(theme, 'Device', 'RTX 3050 Ti'),
                _buildSimpleStat(theme, 'Models', '12 Found'),
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

  Widget _buildModelBundleCard(BuildContext context, WidgetRef ref, SettingsState settings) {
    final theme = Theme.of(context);
    final isDownloading = settings.isDownloadingBundle;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Qwen3 AI Model Bundle',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Install the recommended Qwen3 suite (Instruct + Embedding + Reranker) for a complete local AI experience.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 16),
            _buildModelStatusItem(theme, 'Instruct (4B)', settings.isInstructInstalled),
            const Divider(height: 8, indent: 32),
            _buildModelStatusItem(theme, 'Embedding (0.6B)', settings.isEmbeddingInstalled),
            const Divider(height: 8, indent: 32),
            _buildModelStatusItem(theme, 'Reranker (0.6B)', settings.isRerankerInstalled),
            const SizedBox(height: 20),
            if (isDownloading) ...[
              LinearProgressIndicator(
                value: settings.bundleProgress,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                settings.bundleStatus,
                style: theme.textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
              ),
            ] else if (settings.isInstructInstalled && settings.isEmbeddingInstalled && settings.isRerankerInstalled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Bundle Fully Installed',
                      style: theme.textTheme.labelMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => ref.read(settingsProvider.notifier).downloadModelBundle(),
                  icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                  label: const Text('Download Bundle (Approx. 4GB)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelStatusItem(ThemeData theme, String name, bool installed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            installed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: installed ? Colors.green : theme.hintColor.withValues(alpha: 0.5),
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: installed ? null : theme.hintColor,
              fontWeight: installed ? FontWeight.w500 : null,
            ),
          ),
          const Spacer(),
          if (installed)
            Text(
              'Downloaded',
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
            )
          else
            Text(
              'Pending',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
        ],
      ),
    );
  }

  Widget _buildHardwareSection(BuildContext context, WidgetRef ref, SettingsState settings) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hardware Optimization',
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSettingRow(
                  theme,
                  'Engine Type',
                  'Vulkan (Cross-Vendor GPU)',
                  const Icon(Icons.bolt, size: 20, color: Colors.orange),
                ),
                const Divider(height: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.memory, size: 20),
                        const SizedBox(width: 12),
                        Text('Process on Device', style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        if (settings.availableDevices.isEmpty && settings.selectedEngine != null)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (settings.availableDevices.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: Key('${settings.selectedDeviceId}_${settings.availableDevices.length}'),
                              initialValue: settings.availableDevices.any((d) => d.id == settings.selectedDeviceId)
                                  ? settings.selectedDeviceId
                                  : 'cpu',
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                fillColor: theme.colorScheme.surface,
                                filled: true,
                              ),
                              items: settings.availableDevices.map((device) {
                                return DropdownMenuItem<String>(
                                  value: device.id,
                                  child: Text(
                                    device.name,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(settingsProvider.notifier).setSelectedDevice(val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: 'Refresh Hardware List',
                            onPressed: () => ref.read(settingsProvider.notifier).fetchDevices(),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Select or download an engine to see available hardware.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(ThemeData theme, String label, String value, Widget icon) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEngineSelectionSection(BuildContext context, ThemeData theme, WidgetRef ref, SettingsState settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Engines (GitHub)',
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
            ),
            if (settings.isFetchingEngines)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Check for Updates',
                onPressed: () => ref.read(settingsProvider.notifier).fetchEngines(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildFolderCard(
          context: context,
          theme: theme,
          label: 'Engines Location',
          path: settings.enginesPath.isEmpty ? 'Not set' : settings.enginesPath,
          onFolderTap: () => ref.read(settingsProvider.notifier).openEngineFolder(),
          onChevronTap: () => ref.read(settingsProvider.notifier).openEngineFolder(),
        ),
        const SizedBox(height: 12),
        if (settings.isDownloading) ...[
          LinearProgressIndicator(value: settings.downloadProgress),
          const SizedBox(height: 8),
          Text(
            settings.downloadStatus,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
        ],
        if (settings.availableEngines.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No engines found for your platform.'),
          ))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: settings.availableEngines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final asset = settings.availableEngines[index];
                final isSelected = settings.selectedEngine == asset.name;
                final engineFolderName = p.basenameWithoutExtension(asset.name);
                final isInstalled = settings.installedEngineNames.contains(engineFolderName);
                final sizeMb = (asset.size / (1024 * 1024)).toStringAsFixed(1);

                return ListTile(
                  dense: true,
                  title: Text(asset.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text('$sizeMb MB${!isInstalled && isSelected ? " (Missing files!)" : ""}'),
                  trailing: (isInstalled && isSelected)
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                          icon: Icon(
                            isSelected ? Icons.replay_rounded : Icons.download,
                            size: 20,
                            color: isSelected ? theme.colorScheme.primary : null,
                          ),
                          tooltip: isSelected ? 'Re-download Missing Files' : 'Download',
                          onPressed: settings.isDownloading 
                              ? null 
                              : () => ref.read(settingsProvider.notifier).downloadEngine(asset),
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelLibrarySection(BuildContext context, ThemeData theme, WidgetRef ref, SettingsState settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Model Library',
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        _buildFolderCard(
          context: context,
          theme: theme,
          label: 'Models Location',
          path: settings.modelsPath.isEmpty ? 'Select folder' : settings.modelsPath,
          onFolderTap: () => ref.read(settingsProvider.notifier).openModelsFolder(),
          onChevronTap: () async {
            String? result = await FilePicker.platform.getDirectoryPath();
            if (result != null) {
              ref.read(settingsProvider.notifier).updateModelsPath(result);
            }
          },
        ),
      ],
    );
  }

  Widget _buildFolderCard({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required String path,
    required VoidCallback onFolderTap,
    required VoidCallback onChevronTap,
  }) {
    return InkWell(
      onTap: onFolderTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_open, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium),
                  Text(
                    path,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: path == 'Not set' || path == 'Select folder' 
                          ? theme.colorScheme.onSurfaceVariant 
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onChevronTap,
              icon: const Icon(Icons.chevron_right, size: 16),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogsModal(BuildContext context, SettingsState settings, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final currentSettings = ref.watch(settingsProvider);
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.terminal, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'llama-server logs',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_sweep, color: Colors.white70, size: 20),
                            onPressed: () => ref.read(settingsProvider.notifier).clearLogs(),
                            tooltip: 'Clear Logs',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    child: currentSettings.serverLogs.isEmpty
                        ? const Center(
                            child: Text(
                              'No logs recorded yet.',
                              style: TextStyle(color: Colors.white38, fontFamily: 'monospace'),
                            ),
                          )
                        : ListView.builder(
                            reverse: true, // Show latest at bootom, scrollable upwards
                            itemCount: currentSettings.serverLogs.length,
                            itemBuilder: (context, index) {
                              final log = currentSettings.serverLogs[currentSettings.serverLogs.length - 1 - index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text(
                                  log,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}
