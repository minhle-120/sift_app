import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/settings_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/collection_controller.dart';
import '../views/settings_screen.dart';
import '../../../../../core/models/ai_models.dart';

class ChatInputField extends ConsumerStatefulWidget {
  const ChatInputField({super.key});

  @override
  ConsumerState<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends ConsumerState<ChatInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

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
    if (text.isNotEmpty) {
      final collectionState = ref.read(collectionProvider);
      ref.read(chatControllerProvider.notifier).sendMessage(text, collectionState.activeCollection?.id);
      _controller.clear();
      _focusNode.requestFocus();
    }
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
                    label: settings.chatModel.isEmpty ? 'Select Model' : settings.chatModel,
                    onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                  const SizedBox(width: 8),
                  
                  // Visualizer Toggle
                  _buildTrayAction(
                    context,
                    icon: _getVisualizerIcon(settings.visualizerMode),
                    label: 'Visualizer: ${_getVisualizerLabel(settings.visualizerMode)}',
                    isHighlight: settings.visualizerMode != VisualizerMode.off,
                    onPressed: () => _cycleVisualizerMode(settings, settingsNotifier),
                  ),
                  
                  // Future toggles go here
                  const SizedBox(width: 12),
                  Icon(Icons.circle, size: 4, color: theme.colorScheme.outlineVariant),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Input Pill
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _focusNode.hasFocus 
                      ? theme.colorScheme.primary.withAlpha(127)
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {},
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !chatState.isLoading,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: chatState.isLoading ? 'Thinking...' : 'Message Sift...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 6),
                    child: chatState.isLoading 
                      ? IconButton(
                          icon: Icon(Icons.stop_circle, color: theme.colorScheme.error),
                          onPressed: _stopResponse,
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_upward_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: _hasText ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh,
                            foregroundColor: _hasText ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant.withAlpha(100),
                          ),
                          onPressed: _hasText ? _sendMessage : null,
                        ),
                  ),
                ],
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
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 14, color: color.withAlpha(127)),
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
}
