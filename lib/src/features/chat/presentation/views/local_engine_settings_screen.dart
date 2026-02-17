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
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Launch on Startup'),
            subtitle: const Text('Automatically start the server when Sift opens'),
            value: settings.autoStartServer,
            onChanged: (val) => ref.read(settingsProvider.notifier).updateAutoStartServer(val),
            secondary: const Icon(Icons.bolt),
          ),
          const SizedBox(height: 24),
          _buildHardwareSection(context, ref, settings),
          const SizedBox(height: 24),
          _buildEngineSelectionSection(context, theme, ref, settings),
          const SizedBox(height: 24),
          _buildModelLibrarySection(context, theme, ref, settings),
          const SizedBox(height: 16),
          _buildModelBundleCard(context, ref, settings),
          if (!settings.isSetupComplete) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: (settings.isEngineVerified && settings.isInstructInstalled)
                    ? () {
                        Navigator.of(context).pop();
                        ref.read(settingsProvider.notifier).completeSetup();
                      }
                    : null,
                child: const Text('Finish Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, ThemeData theme, WidgetRef ref, SettingsState settings) {
    // Dynamic status
    final Color statusColor;
    final String statusLabel;
    final bool isModelsReady = settings.isInstructInstalled && settings.isEmbeddingInstalled && settings.isRerankerInstalled;

    if (settings.isServerRunning) {
      statusColor = Colors.green;
      statusLabel = 'Server Running';
    } else if (settings.isEngineVerified && isModelsReady) {
      statusColor = Colors.orange;
      statusLabel = 'Server Stopped';
    } else if (settings.isEngineVerified && !isModelsReady) {
      statusColor = Colors.orange;
      statusLabel = 'Models Missing';
    } else {
      statusColor = Colors.grey;
      statusLabel = 'Not Ready';
    }

    // Compute stats
    final deviceName = settings.availableDevices
        .where((d) => d.id == settings.selectedDeviceId)
        .map((d) => d.name)
        .firstOrNull ?? 'None';
    final engineStatus = settings.isEngineVerified ? 'Ready' : 'Missing';
    final configStatus = settings.isConfigReady ? 'Ready' : 'Missing';
    final modelsStatus = isModelsReady ? 'Ready' : 'Missing';

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
            // Top row: status + actions
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  statusLabel,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _showLogsModal(context, settings, ref),
                  icon: const Icon(Icons.terminal, size: 18),
                  label: const Text('Logs'),
                ),
                const SizedBox(width: 8),
                settings.isServerRunning
                    ? FilledButton.icon(
                        onPressed: () => ref.read(settingsProvider.notifier).stopServer(),
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: const Text('Stop'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: (settings.isEngineVerified && isModelsReady)
                            ? () => ref.read(settingsProvider.notifier).startServer()
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Start'),
                      ),
              ],
            ),

            // Config management row
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  settings.isConfigReady ? Icons.description_outlined : Icons.warning_amber_rounded,
                  size: 16,
                  color: settings.isConfigReady ? theme.hintColor : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    settings.configPath.isNotEmpty
                        ? p.basename(settings.configPath)
                        : 'sift_config.ini',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.hintColor,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ref.read(settingsProvider.notifier).openConfig(),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => ref.read(settingsProvider.notifier).resetConfig(),
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            // Stats row
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSimpleStat(theme, 'Engine', engineStatus),
                _buildSimpleStat(theme, 'Device', deviceName.length > 12 ? '${deviceName.substring(0, 12)}…' : deviceName),
                _buildSimpleStat(theme, 'Config', configStatus),
                _buildSimpleStat(theme, 'Models', modelsStatus),
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
        // Section header with status summary
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Inference Engine',
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
                tooltip: 'Verify & Refresh',
                onPressed: () => ref.read(settingsProvider.notifier).fetchEngines(),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Current engine status card (filesystem-verified)
        _buildCurrentEngineStatus(context, theme, ref, settings),
        const SizedBox(height: 12),

        // Download progress
        if (settings.isDownloading) ...[
          LinearProgressIndicator(value: settings.downloadProgress),
          const SizedBox(height: 8),
          Text(
            settings.downloadStatus,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 12),
        ],

        // Engine location
        _buildFolderCard(
          context: context,
          theme: theme,
          label: 'Engines Location',
          path: settings.enginesPath.isEmpty ? 'Not set' : settings.enginesPath,
          onFolderTap: () => ref.read(settingsProvider.notifier).openEngineFolder(),
          onChevronTap: () => ref.read(settingsProvider.notifier).openEngineFolder(),
        ),
        const SizedBox(height: 12),

        // Available engines list
        if (settings.availableEngines.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              settings.isFetchingEngines ? 'Fetching...' : 'No engines found for your platform.',
              style: theme.textTheme.bodySmall,
            ),
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
                  final engineFolderName = p.basenameWithoutExtension(asset.name);
                  final isOnDisk = settings.installedEngineName == engineFolderName;
                  final isSelected = settings.selectedEngine == asset.name;
                  final sizeMb = (asset.size / (1024 * 1024)).toStringAsFixed(1);

                  // Determine status
                  Widget trailing;
                  Widget? subtitle;

                  if (isOnDisk && isSelected) {
                    // ✅ Installed & verified on disk
                    trailing = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, color: Colors.green, size: 14),
                          SizedBox(width: 4),
                          Text('Installed', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                    subtitle = Text('$sizeMb MB · Verified on disk', style: TextStyle(fontSize: 11, color: Colors.green.withValues(alpha: 0.8)));
                  } else if (isOnDisk && !isSelected) {
                    // 🔄 On disk but not the selected one (edge case, shouldn't happen often)
                    trailing = IconButton(
                      icon: const Icon(Icons.download, size: 20),
                      tooltip: 'Download this version',
                      onPressed: settings.isDownloading ? null : () => ref.read(settingsProvider.notifier).downloadEngine(asset),
                    );
                    subtitle = Text('$sizeMb MB', style: const TextStyle(fontSize: 11));
                  } else if (settings.isEngineVerified && !isOnDisk) {
                    // 🔄 An engine exists but a newer version is available 
                    trailing = TextButton.icon(
                      icon: const Icon(Icons.upgrade_rounded, size: 16),
                      label: const Text('Update', style: TextStyle(fontSize: 11)),
                      onPressed: settings.isDownloading ? null : () => ref.read(settingsProvider.notifier).downloadEngine(asset),
                    );
                    subtitle = Text('$sizeMb MB · Newer version', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary));
                  } else {
                    // ⬇️ No engine at all, fresh download
                    trailing = IconButton(
                      icon: const Icon(Icons.download_rounded, size: 20),
                      tooltip: 'Download',
                      onPressed: settings.isDownloading ? null : () => ref.read(settingsProvider.notifier).downloadEngine(asset),
                    );
                    subtitle = Text('$sizeMb MB', style: const TextStyle(fontSize: 11));
                  }

                  return ListTile(
                    dense: true,
                    title: Text(
                      asset.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isOnDisk ? FontWeight.w600 : null,
                      ),
                    ),
                    subtitle: subtitle,
                    trailing: trailing,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentEngineStatus(BuildContext context, ThemeData theme, WidgetRef ref, SettingsState settings) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;
    final String statusDetail;

    if (settings.isEngineVerified && settings.installedEngineName != null) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Engine Ready';
      statusDetail = settings.installedEngineName!;
    } else if (settings.selectedEngine != null && !settings.isEngineVerified) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
      statusText = 'Engine Missing';
      statusDetail = 'Binary not found on disk. Re-download required.';
    } else {
      statusColor = theme.hintColor;
      statusIcon = Icons.info_outline_rounded;
      statusText = 'No Engine';
      statusDetail = 'Download an engine below to get started.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: theme.textTheme.labelLarge?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  statusDetail,
                  style: theme.textTheme.bodySmall?.copyWith(color: statusColor.withValues(alpha: 0.8), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
