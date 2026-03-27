import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/settings_controller.dart';
import '../../../knowledge/presentation/controllers/knowledge_controller.dart';
import 'local_engine_settings_screen.dart';
import 'mobile_engine_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _urlController = TextEditingController(text: settings.llamaServerUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes to update controller if needed (e.g. external updates)
    ref.listen(settingsProvider, (previous, next) {
      if (next.llamaServerUrl != _urlController.text) {
        _urlController.text = next.llamaServerUrl;
      }
    });

    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final isMobileInternal = (Platform.isAndroid || Platform.isIOS) && settings.backendType == BackendType.internal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: (MediaQuery.of(context).size.width * 0.95).clamp(0.0, 900.0),
          child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // AI Backend
          Text(
            'AI Backend',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          
          SegmentedButton<BackendType>(
            segments: const [
              ButtonSegment<BackendType>(
                value: BackendType.external,
                label: Text('External'),
                icon: Icon(Icons.cloud_outlined),
              ),
              ButtonSegment<BackendType>(
                value: BackendType.internal,
                label: Text('Internal'),
                icon: Icon(Icons.memory),
              ),
            ],
            selected: {settings.backendType},
            onSelectionChanged: (Set<BackendType> newSelection) {
              ref.read(settingsProvider.notifier).updateBackendType(newSelection.first);
            },
          ),
          
          const SizedBox(height: 24),

          if (settings.backendType == BackendType.external) ...[
            TextField(
              controller: _urlController,
              onChanged: (val) => ref.read(settingsProvider.notifier).updateLlamaServerUrl(val),
              onSubmitted: (_) => ref.read(settingsProvider.notifier).fetchModels(),
              decoration: InputDecoration(
                labelText: 'Llama.cpp Server URL',
                border: const OutlineInputBorder(),
                helperText: 'e.g. http://localhost:8080',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: settings.isLoadingModels 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.read(settingsProvider.notifier).fetchModels(),
                      tooltip: 'Connect',
                    ),
              ),
            ),
          ] else ...[
          if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) ...[
            // Local AI Executive Navigation
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.terminal_rounded),
                title: const Text('Configure Local AI Engine'),
                subtitle: const Text('Manage hardware, models, and engine status'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LocalEngineSettingsScreen()),
                  );
                },
              ),
            ),
          ] else if (Platform.isAndroid || Platform.isIOS) ...[
            // Mobile AI Engine Placeholder
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.primaryContainer),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(Icons.phone_android, color: theme.colorScheme.primary),
                title: const Text('Mobile AI Engine'),
                subtitle: const Text('Integrated LiteRT & MediaPipe backend'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MobileEngineSettingsScreen()),
                  );
                },
              ),
            ),
          ],
        ],
          
          const SizedBox(height: 32),

          // Model Selection
          Opacity(
            opacity: isMobileInternal ? 0.5 : 1.0,
            child: AbsorbPointer(
              absorbing: isMobileInternal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Model Selection',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (settings.isLoadingModels)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (!isMobileInternal)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => ref.read(settingsProvider.notifier).fetchModels(),
                          tooltip: 'Refresh Models',
                        ),
                    ],
                  ),
                  if (isMobileInternal)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.lock_clock_outlined, size: 14, color: theme.hintColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Managed by Mobile AI Engine above.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (settings.error != null && !isMobileInternal)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        settings.error!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  _buildModelDropdown(
                    theme,
                    label: 'Chat Model',
                    value: settings.chatModel,
                    items: settings.availableModels,
                    onChanged: (val) {
                      if (val != null) ref.read(settingsProvider.notifier).updateChatModel(val);
                    },
                    icon: Icons.smart_toy_outlined,
                  ),
                  
                  const SizedBox(height: 16),
        
                  _buildModelDropdown(
                    theme,
                    label: 'Embedding Model',
                    value: settings.embeddingModel,
                    items: settings.availableModels,
                    onChanged: (val) {
                      if (val != null) ref.read(settingsProvider.notifier).updateEmbeddingModel(val);
                    },
                    icon: Icons.numbers,
                  ),
                  
                  if (settings.embeddingModel.isNotEmpty && !isMobileInternal) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          settings.detectedEmbeddingDimension != null 
                              ? 'Auto-detected Dimension: ${settings.detectedEmbeddingDimension}'
                              : 'Detecting dimension...',
                          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: theme.hintColor),
                        ),
                      ],
                    ),
                  ],
        
                  const SizedBox(height: 16),
                  
                  _buildModelDropdown(
                    theme,
                    label: 'Rerank Model',
                    value: settings.rerankModel,
                    items: settings.availableModels,
                    onChanged: (val) {
                      if (val != null) ref.read(settingsProvider.notifier).updateRerankModel(val);
                    },
                    icon: Icons.sort,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Document Processing & RAG
          Text(
            'Document Processing & RAG',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.splitscreen, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Chunking Configuration',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Chunk Size (Words)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          controller: TextEditingController(text: settings.chunkSize.toString())
                            ..selection = TextSelection.fromPosition(
                                TextPosition(offset: settings.chunkSize.toString().length)),
                          onChanged: (val) {
                            final size = int.tryParse(val);
                            if (size != null) {
                              ref.read(settingsProvider.notifier).updateChunkSize(size);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Overlap (Words)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          controller: TextEditingController(text: settings.chunkOverlap.toString())
                            ..selection = TextSelection.fromPosition(
                                TextPosition(offset: settings.chunkOverlap.toString().length)),
                          onChanged: (val) {
                            final overlap = int.tryParse(val);
                            if (overlap != null) {
                              ref.read(settingsProvider.notifier).updateChunkOverlap(overlap);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.refresh_rounded, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Index Maintenance', style: theme.textTheme.titleSmall),
                            Text(
                              'Re-chunk and re-embed all documents if you changed the embedding model or chunk size.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Consumer(
                    builder: (context, ref, child) {
                      final knowledgeState = ref.watch(knowledgeControllerProvider);
                      final isReprocessing = knowledgeState.isReprocessing;
                      final progress = knowledgeState.reprocessingProgress;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isReprocessing) ...[
                             Row(
                               children: [
                                 Expanded(
                                   child: LinearProgressIndicator(
                                     value: progress,
                                     borderRadius: BorderRadius.circular(4),
                                   ),
                                 ),
                                 const SizedBox(width: 12),
                                 Text(
                                   '${(progress * 100).toStringAsFixed(0)}%',
                                   style: theme.textTheme.labelMedium?.copyWith(
                                     fontWeight: FontWeight.bold,
                                     color: theme.colorScheme.primary,
                                   ),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 12),
                          ],
                          FilledButton.icon(
                            onPressed: isReprocessing || settings.embeddingModel.isEmpty
                                ? null
                                : () => ref.read(knowledgeControllerProvider.notifier).reprocessAllDocuments(),
                            icon: isReprocessing 
                                ? Container(
                                    width: 16, 
                                    height: 16, 
                                    padding: const EdgeInsets.all(2),
                                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: Text(isReprocessing ? 'Reprocessing...' : 'Reprocess All Documents'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Device Sync
          Text(
            'Device Sync',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0, // M3 style flat card or outlined
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              title: const Text('Sync on this device'),
              subtitle: const Text('Enable synchronization with other devices'),
              value: settings.isSyncEnabled,
              onChanged: (val) => ref.read(settingsProvider.notifier).toggleSync(val),
              secondary: const Icon(Icons.sync),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildModelDropdown(
    ThemeData theme, {
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    // Check if the current value is genuinely available on the server
    
    // Ensure value is in items for the DropdownButton to work correctly
    String? dropdownValue = items.contains(value) ? value : null;
    
    // If value is set but not in items (e.g. manually set before or legacy), 
    // add it to the list temporarily for display purposes
    List<String> displayItems = List.from(items);
    if (value.isNotEmpty && !items.contains(value)) {
       displayItems.add(value);
       dropdownValue = value;
    }

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: dropdownValue,
          isExpanded: true,
          isDense: true,
          onChanged: onChanged,
          items: displayItems.map((String item) {
            final bool itemAvailable = items.contains(item);
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Expanded(child: Text(item, overflow: TextOverflow.ellipsis)),
                  if (item.isNotEmpty)
                    Icon(
                      itemAvailable ? Icons.check_circle : Icons.error_outline,
                      size: 14,
                      color: itemAvailable ? Colors.green.withValues(alpha: 0.7) : theme.colorScheme.error.withValues(alpha: 0.7),
                    ),
                ],
              ),
            );
          }).toList(),
          hint: const Text('Select a model'),
        ),
      ),
    );
  }
}
