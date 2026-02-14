import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/settings_controller.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Server Connection
          Text(
            'Server Connection',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            onChanged: (val) => ref.read(settingsProvider.notifier).updateLlamaServerUrl(val),
            decoration: const InputDecoration(
              labelText: 'Llama.cpp Server URL',
              border: OutlineInputBorder(),
              helperText: 'e.g. http://localhost:8080',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          
          const SizedBox(height: 32),

          // Model Selection
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
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.read(settingsProvider.notifier).fetchModels(),
                  tooltip: 'Refresh Models',
                ),
            ],
          ),
          if (settings.error != null)
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

          const SizedBox(height: 16),
          
          // Embedding Configuration Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dimensions',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        controller: TextEditingController(text: settings.embeddingDimensions.toString())
                          ..selection = TextSelection.fromPosition(
                              TextPosition(offset: settings.embeddingDimensions.toString().length)),
                        onChanged: (val) {
                          final dim = int.tryParse(val);
                          if (dim != null) {
                            ref.read(settingsProvider.notifier).updateEmbeddingDimensions(dim);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
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
              ],
            ),
          ),

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
    // Ensure value is in items, or null if items is empty
    String? dropdownValue = items.contains(value) ? value : null;
    
    // If value is set but not in items (e.g. manually set before or legacy), 
    // we might want to still show it or add it to items. 
    // For now, let's just add it if it's not empty and items is not empty
    if (value.isNotEmpty && !items.contains(value)) {
       // Option: add it to the list temporarily so it can be selected?
       // Or just default to null/first?
       // Let's add it to the list of items for display
       items = [...items, value];
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
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          hint: const Text('Select a model'),
        ),
      ),
    );
  }
}
