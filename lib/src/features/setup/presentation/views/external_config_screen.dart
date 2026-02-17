import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sift_app/src/features/chat/presentation/controllers/settings_controller.dart';

class ExternalConfigScreen extends ConsumerStatefulWidget {
  const ExternalConfigScreen({super.key});

  @override
  ConsumerState<ExternalConfigScreen> createState() => _ExternalConfigScreenState();
}

class _ExternalConfigScreenState extends ConsumerState<ExternalConfigScreen> {
  late TextEditingController _urlController;
  late TextEditingController _dimController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _urlController = TextEditingController(text: settings.llamaServerUrl);
    _dimController = TextEditingController(text: settings.embeddingDimensions.toString());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _dimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure External Server'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Details',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'Server URL',
                          hintText: 'http://localhost:8080',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                        onChanged: (val) => ref.read(settingsProvider.notifier).updateLlamaServerUrl(val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: settings.isLoadingModels 
                          ? null 
                          : () => ref.read(settingsProvider.notifier).fetchModels(),
                        icon: settings.isLoadingModels 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh),
                        label: const Text('Connect'),
                      ),
                    ),
                  ],
                ),
                if (settings.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    settings.error!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 32),
                
                Text(
                  'Model Selection',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the specific models your llama.cpp server is currently serving with --models-preset.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 20),

                _buildDropdown(
                  label: 'Chat Model (LLM)',
                  value: settings.chatModel,
                  items: settings.availableModels,
                  onChanged: (val) => ref.read(settingsProvider.notifier).updateChatModel(val!),
                  icon: Icons.chat_bubble_outline,
                ),
                const SizedBox(height: 16),

                _buildDropdown(
                  label: 'Embedding Model',
                  value: settings.embeddingModel,
                  items: settings.availableModels,
                  onChanged: (val) => ref.read(settingsProvider.notifier).updateEmbeddingModel(val!),
                  icon: Icons.psychology_outlined,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _dimController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Embedding Dimensions',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.architecture),
                    helperText: 'Common values: 1024, 768, 512',
                  ),
                  onChanged: (val) {
                    final dim = int.tryParse(val);
                    if (dim != null) {
                      ref.read(settingsProvider.notifier).updateEmbeddingDimensions(dim);
                    }
                  },
                ),
                const SizedBox(height: 16),

                _buildDropdown(
                  label: 'Rerank Model',
                  value: settings.rerankModel,
                  items: settings.availableModels,
                  onChanged: (val) => ref.read(settingsProvider.notifier).updateRerankModel(val!),
                  icon: Icons.reorder,
                ),
                
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: (settings.chatModel.isNotEmpty && !settings.isLoadingModels)
                      ? () {
                          Navigator.of(context).pop();
                          ref.read(settingsProvider.notifier).completeSetup();
                        }
                      : null,
                    child: const Text('Finish Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    // Ensure the current value is in items, or add it if empty/missing
    final dropdownItems = items.contains(value) ? items : [if (value.isNotEmpty) value, ...items];
    if (dropdownItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).hintColor),
            const SizedBox(width: 12),
            Text('Connect to fetch models', style: TextStyle(color: Theme.of(context).hintColor)),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      items: dropdownItems.map((model) => DropdownMenuItem(
        value: model,
        child: Text(model, overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: onChanged,
    );
  }
}
