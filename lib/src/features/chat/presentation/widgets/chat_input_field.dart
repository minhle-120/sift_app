import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:desktop_drop/desktop_drop.dart';
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
  bool _isDragging = false;
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

  Future<void> _handleClipboardPaste() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;

    final reader = await clipboard.read();
    
    // 1. Handle Images
    if (reader.canProvide(Formats.png)) {
      reader.getFile(Formats.png, (file) async {
        final bytes = await file.readAll();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'pasted_image_$timestamp.png';
        
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        await File(filePath).writeAsBytes(bytes);

        if (mounted) {
          setState(() {
            _attachments.add(PlatformFile(
              name: fileName,
              path: filePath,
              size: bytes.length,
              bytes: bytes,
            ));
          });
        }
      });
    } else {
      // If it's just text and we triggered this manually (via button), 
      // we could paste it into the controller, but usually the system does this.
      if (reader.canProvide(Formats.plainText)) {
        final text = await reader.readValue(Formats.plainText);
        if (text != null && mounted) {
          final currentText = _controller.text;
          final selection = _controller.selection;
          final newText = currentText.replaceRange(
            selection.start >= 0 ? selection.start : currentText.length,
            selection.end >= 0 ? selection.end : currentText.length,
            text,
          );
          _controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
              offset: (selection.start >= 0 ? selection.start : currentText.length) + text.length,
            ),
          );
        }
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

  Future<void> _handleFilesDropped(DropDoneDetails details) async {
    if (details.files.isEmpty) return;

    final newFiles = <PlatformFile>[];
    for (final xFile in details.files) {
      final bytes = await xFile.readAsBytes();
      newFiles.add(PlatformFile(
        name: xFile.name,
        path: xFile.path,
        size: bytes.length,
        bytes: bytes,
      ));
    }

    if (mounted) {
      setState(() {
        _attachments.addAll(newFiles);
      });
    }
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
      child: DropTarget(
        onDragDone: _handleFilesDropped,
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              decoration: BoxDecoration(
                color: _isDragging 
                    ? theme.colorScheme.primaryContainer.withAlpha(50) 
                    : theme.colorScheme.surface.withAlpha(180),
                border: _isDragging 
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(60))),
              ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  
                  // Mode Indicator Button
                  _buildTrayAction(
                    context,
                    icon: settings.aiMode == AiMode.brainstorm 
                        ? Icons.lightbulb_outline_rounded 
                        : (settings.aiMode == AiMode.lite ? Icons.flash_on_rounded : Icons.manage_search_rounded),
                    label: '${settings.aiMode.name[0].toUpperCase()}${settings.aiMode.name.substring(1)}',
                    isHighlight: false, // Keep non-highlighted always
                    onPressed: () => _cycleAiMode(settings, settingsNotifier),
                  ),
                  const SizedBox(width: 8),

                  // Tool Toggles (Only in Research Mode)
                  if (!settings.isMobileInternal && settings.aiMode == AiMode.research) ...[
                    _buildTrayAction(
                      context,
                      icon: _getGraphGeneratorIcon(settings.graphGeneratorMode),
                      label: 'Graph: ${_getGraphGeneratorLabel(settings.graphGeneratorMode)}',
                      isHighlight: settings.graphGeneratorMode != GraphGeneratorMode.off,
                      onPressed: () => _cycleGraphGeneratorMode(settings, settingsNotifier),
                    ),
                    const SizedBox(width: 8),
                    _buildTrayAction(
                      context,
                      icon: _getCoderIcon(settings.coderMode),
                      label: 'Code: ${_getCoderLabel(settings.coderMode)}',
                      isHighlight: settings.coderMode != CoderMode.off,
                      onPressed: () => _cycleCoderMode(settings, settingsNotifier),
                    ),
                    const SizedBox(width: 8),
                    _buildTrayAction(
                      context,
                      icon: _getFlashcardIcon(settings.flashcardMode),
                      label: 'Flashcard: ${_getFlashcardLabel(settings.flashcardMode)}',
                      isHighlight: settings.flashcardMode != FlashcardMode.off,
                      onPressed: () => _cycleFlashcardMode(settings, settingsNotifier),
                    ),
                    const SizedBox(width: 8),
                    _buildTrayAction(
                      context,
                      icon: _getInteractiveCanvasIcon(settings.interactiveCanvasMode),
                      label: 'Canvas: ${_getInteractiveCanvasLabel(settings.interactiveCanvasMode)}',
                      isHighlight: settings.interactiveCanvasMode != InteractiveCanvasMode.off,
                      onPressed: () => _cycleInteractiveCanvasMode(settings, settingsNotifier),
                    ),
                    const SizedBox(width: 8),
                  ],


                  
                  // Future toggles go here
                  const SizedBox(width: 12),
                ],
              ),
            ),
            const SizedBox(height: 12),


            // Guidance/Blocker if no documents (only if NOT in Brainstorm Mode)
            if (!collectionState.hasDocuments && collectionState.activeCollection != null && settings.aiMode != AiMode.brainstorm)
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
                // Intercept Paste for images on Desktop
                const SingleActivator(LogicalKeyboardKey.keyV, control: true): _handleClipboardPaste,
                const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _handleClipboardPaste,

                const SingleActivator(LogicalKeyboardKey.enter): () {
                    if (!chatState.isLoading && (_hasText || _attachments.isNotEmpty) && (collectionState.hasDocuments || settings.aiMode == AiMode.brainstorm)) {
                      _sendMessage();
                    }
                  },
                  const SingleActivator(LogicalKeyboardKey.enter, shift: true): () {
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
                  enabled: (collectionState.hasDocuments || settings.aiMode == AiMode.brainstorm),
                  readOnly: chatState.isLoading,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: chatState.isLoading 
                        ? 'Thinking...' 
                        : (settings.aiMode == AiMode.brainstorm 
                            ? 'Directly message Sift...'
                            : (!collectionState.hasDocuments ? 'Upload documents to chat' : 'Message Sift...')),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHigh.withAlpha(180),
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
                      padding: const EdgeInsets.only(right: 6),
                      child: chatState.isLoading 
                        ? IconButton(
                            icon: Icon(Icons.stop_circle, color: theme.colorScheme.error),
                            onPressed: _stopResponse,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: ((_hasText || _attachments.isNotEmpty) && (collectionState.hasDocuments || settings.aiMode == AiMode.brainstorm)) 
                                  ? theme.colorScheme.primary 
                                  : Colors.transparent,
                              foregroundColor: ((_hasText || _attachments.isNotEmpty) && (collectionState.hasDocuments || settings.aiMode == AiMode.brainstorm)) 
                                  ? theme.colorScheme.onPrimary 
                                  : theme.colorScheme.onSurfaceVariant.withAlpha(100),
                              minimumSize: const Size(40, 40),
                              maximumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            onPressed: ((_hasText || _attachments.isNotEmpty) && (collectionState.hasDocuments || settings.aiMode == AiMode.brainstorm)) ? _sendMessage : null,
                          ),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (collectionState.hasDocuments || settings.aiMode == AiMode.brainstorm) _sendMessage();
                  },
                ),
              ),
            ],
          ),
        ),
          ),
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

  void _cycleAiMode(SettingsState settings, SettingsController notifier) {
    List<AiMode> modes = AiMode.values.toList();
    if (settings.isMobileInternal) {
      // Mobile internal supports Lite + Brainstorm, but not Research
      modes = [AiMode.lite, AiMode.brainstorm];
    }
    
    final currentIndex = modes.indexOf(settings.aiMode);
    final safeIndex = currentIndex == -1 ? 0 : currentIndex;
    final nextIndex = (safeIndex + 1) % modes.length;
    notifier.updateAiMode(modes[nextIndex]);
  }

  IconData _getGraphGeneratorIcon(GraphGeneratorMode mode) {
    switch (mode) {
      case GraphGeneratorMode.auto: return Icons.auto_awesome_outlined;
      case GraphGeneratorMode.off: return Icons.visibility_off_outlined;
      case GraphGeneratorMode.on: return Icons.visibility_outlined;
    }
  }

  String _getGraphGeneratorLabel(GraphGeneratorMode mode) {
    switch (mode) {
      case GraphGeneratorMode.auto: return 'Auto';
      case GraphGeneratorMode.off: return 'Off';
      case GraphGeneratorMode.on: return 'On';
    }
  }

  void _cycleGraphGeneratorMode(SettingsState settings, SettingsController notifier) {
    final nextIndex = (settings.graphGeneratorMode.index + 1) % GraphGeneratorMode.values.length;
    notifier.updateGraphGeneratorMode(GraphGeneratorMode.values[nextIndex]);
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
      case CoderMode.on: return 'On';
    }
  }

  void _cycleCoderMode(SettingsState settings, SettingsController notifier) {
    final nextIndex = (settings.coderMode.index + 1) % CoderMode.values.length;
    notifier.updateCoderMode(CoderMode.values[nextIndex]);
  }

  IconData _getFlashcardIcon(FlashcardMode mode) {
    switch (mode) {
      case FlashcardMode.auto: return Icons.auto_awesome_outlined;
      case FlashcardMode.off: return Icons.close_rounded;
      case FlashcardMode.on: return Icons.school_outlined;
    }
  }

  String _getFlashcardLabel(FlashcardMode mode) {
    switch (mode) {
      case FlashcardMode.auto: return 'Auto';
      case FlashcardMode.off: return 'Off';
      case FlashcardMode.on: return 'On';
    }
  }

  void _cycleFlashcardMode(SettingsState settings, SettingsController notifier) {
    final nextIndex = (settings.flashcardMode.index + 1) % FlashcardMode.values.length;
    notifier.updateFlashcardMode(FlashcardMode.values[nextIndex]);
  }

  IconData _getInteractiveCanvasIcon(InteractiveCanvasMode mode) {
    switch (mode) {
      case InteractiveCanvasMode.auto: return Icons.auto_awesome_mosaic_rounded;
      case InteractiveCanvasMode.off: return Icons.layers_clear_rounded;
      case InteractiveCanvasMode.on: return Icons.layers_rounded;
    }
  }

  String _getInteractiveCanvasLabel(InteractiveCanvasMode mode) {
    switch (mode) {
      case InteractiveCanvasMode.auto: return 'Auto';
      case InteractiveCanvasMode.off: return 'Off';
      case InteractiveCanvasMode.on: return 'On';
    }
  }

  void _cycleInteractiveCanvasMode(SettingsState settings, SettingsController notifier) {
    final nextIndex = (settings.interactiveCanvasMode.index + 1) % InteractiveCanvasMode.values.length;
    notifier.updateInteractiveCanvasMode(InteractiveCanvasMode.values[nextIndex]);
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
