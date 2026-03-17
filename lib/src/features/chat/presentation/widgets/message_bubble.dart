import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:convert';
import 'dart:io';
import '../../domain/entities/message.dart';
import '../controllers/workbench_controller.dart';
import '../controllers/collection_controller.dart';
import '../controllers/chat_controller.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  bool _isEditing = false;
  bool _isReasoningExpanded = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.text);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final theme = Theme.of(context);

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.surfaceContainerHigh : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(theme, isUser),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            isUser ? 'You' : 'Sift',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isUser ? theme.colorScheme.primary : theme.colorScheme.secondary,
                            ),
                          ),
                          if (widget.message.isEdited) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(Edited)',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!_isEditing) _buildActionMenu(context, ref, isUser),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (widget.message.reasoning != null) _buildReasoning(theme, widget.message.reasoning!),
                  if (_isEditing)
                    _buildEditMode(theme)
                  else
                    MarkdownBody(
                      data: widget.message.text,
                      selectable: false,
                      extensionSet: md.ExtensionSet(
                        [
                          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                          LatexBlockSyntax(),
                        ],
                        [
                          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                          LatexInlineSyntax(),
                          CitationSyntax(),
                        ],
                      ),
                      builders: {
                        'latex': LatexElementBuilder(),
                        'citation': CitationBuilder(
                          context: context,
                          citations: widget.message.citations,
                          onCitationClick: (index, metadata) {
                            final docId = metadata?['documentId'] as int?;
                            final sourceTitle = metadata?['sourceTitle'] as String? ?? 'Document';
                            
                            if (docId != null) {
                              ref.read(workbenchProvider.notifier).addTab(
                                WorkbenchTab(
                                  id: 'doc_$docId',
                                  title: sourceTitle,
                                  icon: Icons.description_outlined,
                                  type: WorkbenchTabType.document,
                                  metadata: metadata,
                                ),
                              );
                            }
                          },
                        ),
                      },
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                        blockquoteDecoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.primary.withValues(alpha: 0.5),
                              width: 4,
                            ),
                          ),
                        ),
                        blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        blockquote: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        code: theme.textTheme.bodyMedium?.copyWith(
                          backgroundColor: Colors.transparent, // Avoid default blocky bg
                          color: theme.colorScheme.primary,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.message.metadata?['attachments'] != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (widget.message.metadata!['attachments'] as List).map((att) {
                        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains((att['extension'] as String?)?.toLowerCase());
                        if (isImage && att['path'] != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(att['path']),
                              width: 200,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attach_file, size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                att['name'] ?? 'File', 
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (widget.message.metadata?['visual_schema'] != null) ...[
                    const SizedBox(height: 12),
                    _buildVisualTrigger(context, ref, theme),
                  ],
                  if (widget.message.metadata?['code_snippet'] != null) ...[
                    const SizedBox(height: 12),
                    _buildCodeTrigger(context, ref, theme),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildEditMode(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _editController,
          maxLines: null,
          autofocus: true,
          style: theme.textTheme.bodyLarge,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _editController.text = widget.message.text;
                });
              },
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final newText = _editController.text.trim();
                if (newText.isNotEmpty && newText != widget.message.text) {
                  final collectionId = ref.read(collectionProvider).activeCollection?.id;
                  ref.read(chatControllerProvider.notifier).editMessage(
                    widget.message.id,
                    newText,
                    collectionId,
                    resend: false,
                  );
                }
                setState(() => _isEditing = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                elevation: 0,
              ),
              child: const Text('Save'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final newText = _editController.text.trim();
                if (newText.isNotEmpty) {
                  final collectionId = ref.read(collectionProvider).activeCollection?.id;
                  ref.read(chatControllerProvider.notifier).editMessage(
                    widget.message.id,
                    newText,
                    collectionId,
                    resend: true,
                  );
                }
                setState(() => _isEditing = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
              ),
              child: const Text('Resend'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionMenu(BuildContext context, WidgetRef ref, bool isUser) {
    final controller = ref.read(chatControllerProvider.notifier);

    return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.copy_rounded,
            tooltip: 'Copy',
            onPressed: () => controller.copyToClipboard(widget.message.text),
          ),
          if (isUser)
            _ActionButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (!isUser)
            _ActionButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Regenerate',
              onPressed: () {
                final collectionId = ref.read(collectionProvider).activeCollection?.id;
                controller.regenerateResponse(widget.message.id, collectionId);
              },
            ),
          _ActionButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete',
            onPressed: () => controller.deleteMessage(widget.message.id),
          ),
        ],
      );
  }

  Widget _buildVisualTrigger(BuildContext context, WidgetRef ref, ThemeData theme) {
    final schemaStr = widget.message.metadata?['visual_schema'] as String?;
    String label = 'View Interactive Graph';
    String tabTitle = 'Visualization';

    if (schemaStr != null) {
      try {
        final Map<String, dynamic> schema = jsonDecode(schemaStr);
        final title = schema['title'] as String?;
        if (title != null && title.isNotEmpty) {
          label = 'View $title';
          tabTitle = title;
        }
      } catch (_) {}
    }

    return ElevatedButton.icon(
      onPressed: () {
        if (schemaStr == null) return;
        
        ref.read(workbenchProvider.notifier).addTab(
          WorkbenchTab(
            id: 'viz_${widget.message.id}',
            title: tabTitle,
            icon: Icons.hub_outlined,
            type: WorkbenchTabType.visualization,
            metadata: {'schema': schemaStr},
          ),
        );
      },
      icon: const Icon(Icons.hub_outlined, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCodeTrigger(BuildContext context, WidgetRef ref, ThemeData theme) {
    final code = widget.message.metadata?['code_snippet'] as String?;
    final title = widget.message.metadata?['code_title'] as String?;
    
    return ElevatedButton.icon(
      onPressed: () {
        if (code == null) return;
        
        ref.read(workbenchProvider.notifier).addTab(
          WorkbenchTab(
            id: 'code_${widget.message.id}',
            title: title ?? 'Generated Code',
            icon: Icons.code_rounded,
            type: WorkbenchTabType.code,
            metadata: {
              'code': code,
              'language': _detectLanguage(code),
            },
          ),
        );
      },
      icon: const Icon(Icons.terminal_rounded, size: 18),
      label: Text(title != null ? 'View $title' : 'View Implementation'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _detectLanguage(String code) {
    final lowerCode = code.toLowerCase();
    if (lowerCode.contains('import') && lowerCode.contains('package:')) return 'dart';
    if (lowerCode.contains('def ') || lowerCode.contains('import os')) return 'python';
    if (lowerCode.contains('function') || lowerCode.contains('const ')) return 'javascript';
    if (lowerCode.contains('<html>')) return 'html';
    if (lowerCode.contains('select ') && lowerCode.contains('from')) return 'sql';
    return 'plaintext';
  }

  Widget _buildAvatar(ThemeData theme, bool isUser) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isUser ? Icons.person_outline : Icons.auto_awesome,
        size: 18,
        color: isUser ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSecondaryContainer,
      ),
    );
  }

  Widget _buildReasoning(ThemeData theme, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isReasoningExpanded = !_isReasoningExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_outlined, 
                    size: 16, 
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thought process', 
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    )
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isReasoningExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.expand_more, 
                      size: 16, 
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SelectableText(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ),
            crossFadeState: _isReasoningExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(
        icon, 
        size: 16, 
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }
}

class CitationSyntax extends md.InlineSyntax {
  CitationSyntax() : super(r'\[{1,2}(?:Chunk\s*)?(\d+)\]{1,2}');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final indexStr = match.group(1);
    final element = md.Element('citation', [md.Text(indexStr!)]);
    parser.addNode(element);
    return true;
  }
}

class CitationBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final Map<String, dynamic>? citations;
  final Function(String, Map<String, dynamic>?)? onCitationClick;

  CitationBuilder({
    required this.context, 
    this.citations,
    this.onCitationClick,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final rawIndex = element.textContent;
    final theme = Theme.of(context);
    
    final metadata = citations?[rawIndex] as Map<String, dynamic>?;
    final sourceTitle = metadata?['sourceTitle'] as String? ?? 'Source details not available';

    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Tooltip(
              message: sourceTitle,
              child: InkWell(
                onTap: () {
                  debugPrint('Clicked citation: $rawIndex');
                  if (onCitationClick != null) {
                    onCitationClick!(rawIndex, metadata);
                  }
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    rawIndex,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
