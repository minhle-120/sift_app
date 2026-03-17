import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../controllers/settings_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/collection_controller.dart';
import '../views/settings_screen.dart';
import '../../../../../core/models/ai_models.dart';
import 'dart:io';

class ChatInputField extends ConsumerStatefulWidget {
  const ChatInputField({super.key});

  @override
  ConsumerState<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends ConsumerState<ChatInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  final List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty || _attachments.isNotEmpty) {
      final collectionState = ref.read(collectionProvider);
      ref.read(chatControllerProvider.notifier).sendMessage(
        text, 
        collectionState.activeCollection?.id,
        attachments: List.from(_attachments),
      );
      _controller.clear();
      setState(() {
        _attachments.clear();
        _hasText = false;
      });
      _focusNode.requestFocus();
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick files: $e')),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _stopResponse() {
    ref.read(chatControllerProvider.notifier).stopResponse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final chatState = ref.watch(chatControllerProvider);
    final collectionState = ref.watch(collectionProvider);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Tray
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Model Selector
                  _buildTrayAction(
                    context,
                    icon: Icons.smart_toy_outlined,
                    label: settings.chatModelDisplay,
                    onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                  const SizedBox(width: 8),
                  
                  // Brainstorm Mode Toggle
                  _buildTrayAction(
                    context,
                    icon: chatState.isBrainstormMode ? Icons.psychology : Icons.psychology_outlined,
                    label: chatState.isBrainstormMode ? 'Brainstorm: ON' : 'Brainstorm: OFF',
                    isHighlight: chatState.isBrainstormMode,
                    onPressed: () => ref.read(chatControllerProvider.notifier).toggleBrainstormMode(),
                  ),
                  const SizedBox(width: 8),

                  // Visualizer Toggle (Hidden in Lite Mode or Brainstorm Mode)
                  if (!settings.isMobileInternal && !chatState.isBrainstormMode) ...[
                    _buildTrayAction(
                      context,
                      icon: _getVisualizerIcon(settings.visualizerMode),
                      label: 'Visualizer: ${_getVisualizerLabel(settings.visualizerMode)}',
                      isHighlight: settings.visualizerMode != VisualizerMode.off,
                      onPressed: () => _cycleVisualizerMode(settings, settingsNotifier),
                    ),
                    const SizedBox(width: 8),
                    _buildTrayAction(
                      context,
                      icon: _getCoderIcon(settings.coderMode),
                      label: 'Coder: ${_getCoderLabel(settings.coderMode)}',
                      isHighlight: settings.coderMode != CoderMode.off,
                      onPressed: () => _cycleCoderMode(settings, settingsNotifier),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Lite Mode Indicator
                  if (settings.isMobileInternal)
                    _buildTrayAction(
                      context,
                      icon: Icons.bolt_rounded,
                      label: 'Lite Mode Enabled',
                      isHighlight: true,
                      onPressed: () {}, // Decorative for now
                    ),
                  
                  // Future toggles go here
                  const SizedBox(width: 12),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Attachment Tray
            if (_attachments.isNotEmpty)
              Container(
                height: 80,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final file = _attachments[index];
                    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(file.extension?.toLowerCase());
                    
                    return Container(
                      width: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Center(
                            child: isImage && file.path != null
                                ? Image.file(
                                    File(file.path!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  )
                                : Icon(
                                    _getFileIcon(file.extension),
                                    color: theme.colorScheme.primary,
                                  ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removeAttachment(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              color: Colors.black54,
                              child: Text(
                                file.name,
                                style: const TextStyle(color: Colors.white, fontSize: 8),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Guidance/Blocker if no documents (only if NOT in Brainstorm Mode)
            if (!collectionState.hasDocuments && collectionState.activeCollection != null && !chatState.isBrainstormMode)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This collection is empty. Please upload documents to start researching, or toggle Brainstorm Mode to chat directly with Sift.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Input Pill
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): () {
                  if (!chatState.isLoading && (_hasText || _attachments.isNotEmpty) && (collectionState.hasDocuments || chatState.isBrainstormMode)) {
                    _sendMessage();
                  }
                },
                const SingleActivator(LogicalKeyboardKey.enter, shift: true): () {
                  // Standard behavior for Shift+Enter is newline, 
                  // but we need to ensure the event isn't swallowed by the parent shortcut
                  final text = _controller.text;
                  final selection = _controller.selection;
                  final newText = text.replaceRange(selection.start, selection.end, '\n');
                  _controller.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: selection.start + 1),
                  );
                },
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: (collectionState.hasDocuments || chatState.isBrainstormMode),
                readOnly: chatState.isLoading,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: chatState.isLoading 
                      ? 'Thinking...' 
                      : (chatState.isBrainstormMode 
                          ? 'Directly message Sift...'
                          : (!collectionState.hasDocuments ? 'Upload documents to chat' : 'Message Sift...')),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: theme.colorScheme.primary.withAlpha(127)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Attach Files',
                      onPressed: _pickFiles,
                    ),
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: chatState.isLoading 
                      ? IconButton(
                          icon: Icon(Icons.stop_circle, color: theme.colorScheme.error),
                          onPressed: _stopResponse,
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_upward_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: ((_hasText || _attachments.isNotEmpty) && (collectionState.hasDocuments || chatState.isBrainstormMode)) 
                                ? theme.colorScheme.primary 
                                : Colors.transparent,
                            foregroundColor: ((_hasText || _attachments.isNotEmpty) && (collectionState.hasDocuments || chatState.isBrainstormMode)) 
                                ? theme.colorScheme.onPrimary 
                                : theme.colorScheme.onSurfaceVariant.withAlpha(100),
                          ),
                          onPressed: ((_hasText || _attachments.isNotEmpty) && (collectionState.hasDocuments || chatState.isBrainstormMode)) ? _sendMessage : null,
                        ),
                  ),
                ),
                onSubmitted: (_) {
                  // onSubmitted is still useful for mobile "Done" button
                  if (collectionState.hasDocuments || chatState.isBrainstormMode) _sendMessage();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrayAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    final color = isHighlight ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isHighlight 
              ? theme.colorScheme.primaryContainer.withAlpha(76) // roughly 0.3
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlight 
                ? theme.colorScheme.primary.withAlpha(127) // roughly 0.5
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label, 
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: isHighlight ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }


  IconData _getVisualizerIcon(VisualizerMode mode) {
    switch (mode) {
      case VisualizerMode.auto: return Icons.auto_awesome_outlined;
      case VisualizerMode.off: return Icons.visibility_off_outlined;
      case VisualizerMode.on: return Icons.visibility_outlined;
    }
  }

  String _getVisualizerLabel(VisualizerMode mode) {
    switch (mode) {
      case VisualizerMode.auto: return 'Auto';
      case VisualizerMode.off: return 'Off';
      case VisualizerMode.on: return 'Always On';
    }
  }

  void _cycleVisualizerMode(SettingsState settings, SettingsController notifier) {
    final nextIndex = (settings.visualizerMode.index + 1) % VisualizerMode.values.length;
    notifier.updateVisualizerMode(VisualizerMode.values[nextIndex]);
  }

  IconData _getCoderIcon(CoderMode mode) {
    switch (mode) {
      case CoderMode.auto: return Icons.code_rounded;
      case CoderMode.off: return Icons.code_off_rounded;
      case CoderMode.on: return Icons.terminal_rounded;
    }
  }

  String _getCoderLabel(CoderMode mode) {
    switch (mode) {
      case CoderMode.auto: return 'Auto';
      case CoderMode.off: return 'Off';
      case CoderMode.on: return 'Always On';
    }
  }

  void _cycleCoderMode(SettingsState settings, SettingsController notifier) {
    final nextIndex = (settings.coderMode.index + 1) % CoderMode.values.length;
    notifier.updateCoderMode(CoderMode.values[nextIndex]);
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx': return Icons.description_outlined;
      case 'txt': return Icons.text_snippet_outlined;
      case 'md': return Icons.article_outlined;
      case 'xls':
      case 'xlsx': return Icons.table_chart_outlined;
      case 'zip':
      case 'rar': return Icons.folder_zip_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }
}
