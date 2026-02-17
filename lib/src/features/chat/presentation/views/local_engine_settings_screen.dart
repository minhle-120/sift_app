import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
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
          _buildStatusCard(theme, settings),
          const SizedBox(height: 24),
          _buildHardwareSection(theme, ref, settings),
          const SizedBox(height: 24),
          _buildEngineSelectionSection(theme, ref, settings),
          const SizedBox(height: 24),
          _buildModelLibrarySection(theme, ref, settings),
          const SizedBox(height: 24),
          _buildDownloadCenter(theme, settings),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, SettingsState settings) {
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

  Widget _buildHardwareSection(ThemeData theme, WidgetRef ref, SettingsState settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hardware Optimization',
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        _buildDropdownSetting(
          theme,
          label: 'Inference Engine',
          value: 'Vulkan', // Hardcoded for UI first
          items: ['CPU Only', 'Vulkan', 'CUDA'],
          icon: Icons.bolt,
          onChanged: (val) {},
        ),
        const SizedBox(height: 16),
        _buildDropdownSetting(
          theme,
          label: 'Primary Device',
          value: settings.gpuDeviceIndex,
          items: [
            {'label': 'Automatic', 'value': 0},
            {'label': 'NVIDIA RTX 3050 Ti', 'value': 1},
            {'label': 'AMD Radeon Graphics', 'value': 2},
          ],
          icon: Icons.memory,
          onChanged: (val) {
             if (val is int) ref.read(settingsProvider.notifier).updateGpuDeviceIndex(val);
          },
        ),
      ],
    );
  }

  Widget _buildEngineSelectionSection(ThemeData theme, WidgetRef ref, SettingsState settings) {
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
          Container(
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              itemCount: settings.availableEngines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final asset = settings.availableEngines[index];
                final isSelected = settings.selectedEngine == asset.name;
                final sizeMb = (asset.size / (1024 * 1024)).toStringAsFixed(1);

                return ListTile(
                  dense: true,
                  title: Text(asset.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text('$sizeMb MB'),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                          icon: const Icon(Icons.download, size: 20),
                          onPressed: settings.isDownloading 
                              ? null 
                              : () => ref.read(settingsProvider.notifier).downloadEngine(asset),
                        ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildModelLibrarySection(ThemeData theme, WidgetRef ref, SettingsState settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Model Library',
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            String? result = await FilePicker.platform.getDirectoryPath();
            if (result != null) {
              ref.read(settingsProvider.notifier).updateModelsPath(result);
            }
          },
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
                      Text('Storage Path', style: theme.textTheme.labelMedium),
                      Text(
                        settings.modelsPath.isEmpty ? 'Select folder to store GGUF models' : settings.modelsPath,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: settings.modelsPath.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadCenter(ThemeData theme, SettingsState settings) {
    final curatedModels = [
      {'name': 'Qwen 2.5 Coder (1.5B)', 'size': '1.2 GB', 'desc': 'Perfect for code assistance.'},
      {'name': 'Llama 3.1 Sift (3B)', 'size': '2.1 GB', 'desc': 'Balanced for general chat.'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended Models',
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
            ),
            TextButton(onPressed: () {}, child: const Text('View All')),
          ],
        ),
        const SizedBox(height: 8),
        ...curatedModels.map((model) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.cloud_download_outlined),
            title: Text(model['name']!),
            subtitle: Text('${model['size']} • ${model['desc']}'),
            trailing: IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: () {},
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildDropdownSetting(
    ThemeData theme, {
    required String label,
    required dynamic value,
    required List<dynamic> items,
    required IconData icon,
    required Function(dynamic) onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: value,
          isExpanded: true,
          isDense: true,
          onChanged: onChanged,
          items: items.map((item) {
            final val = item is Map ? item['value'] : item;
            final text = item is Map ? item['label'] : item.toString();
            return DropdownMenuItem<dynamic>(
              value: val,
              child: Text(text, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        ),
      ),
    );
  }
}
