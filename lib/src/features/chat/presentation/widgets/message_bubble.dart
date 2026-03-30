import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:io';
import '../../domain/entities/message.dart';
import '../controllers/workbench_controller.dart';
import '../controllers/collection_controller.dart';
import '../controllers/chat_controller.dart';
import '../../../../../core/plugins/plugins_provider.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  bool _isEditing = false;
  bool _isReasoningExpanded = false;
  bool _userScrolledReasoning = false;
  bool _isAutoScrolling = false;
  late TextEditingController _editController;
  late ScrollController _reasoningScrollController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.text);
    _reasoningScrollController = ScrollController();
    _reasoningScrollController.addListener(_onReasoningScroll);
  }

  void _onReasoningScroll() {
    if (_isAutoScrolling || !_reasoningScrollController.hasClients) return;
    final pos = _reasoningScrollController.position;
    // If user scrolled away from the bottom, stop auto-following
    if (pos.maxScrollExtent - pos.pixels > 30) {
      _userScrolledReasoning = true;
    } else {
      // If they scrolled back to the absolute bottom, resume following
      _userScrolledReasoning = false;
    }
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.reasoning != null &&
        widget.message.reasoning != oldWidget.message.reasoning &&
        _isReasoningExpanded) {
      // Reset the flag if reasoning just started (was previously null)
      if (oldWidget.message.reasoning == null) {
        _userScrolledReasoning = false;
      }
      if (!_userScrolledReasoning) {
        _scrollReasoningToBottom();
      }
    }
  }

  void _scrollReasoningToBottom() {
    if (_isAutoScrolling || !_reasoningScrollController.hasClients) return;
    
    _isAutoScrolling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_reasoningScrollController.hasClients) {
        _reasoningScrollController
          .animateTo(
            _reasoningScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          )
          .then((_) => _isAutoScrolling = false);
      } else {
        _isAutoScrolling = false;
      }
    });
  }

  @override
  void dispose() {
    _editController.dispose();
    _reasoningScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final theme = Theme.of(context);
    final chatState = ref.watch(chatControllerProvider);

    final margin = isUser 
        ? const EdgeInsets.fromLTRB(16, 4, 16, 4) 
        : const EdgeInsets.symmetric(vertical: 4);

    return Container(
        width: double.infinity,
        margin: margin,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.surfaceContainerHigh : Colors.transparent,
          borderRadius: isUser ? BorderRadius.circular(20) : null,
        ),
        child: isUser 
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(theme, isUser),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderRow(theme, isUser),
                      const SizedBox(height: 4),
                      _buildMainContent(theme, chatState, isUser, context),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderRow(theme, isUser, includeAvatar: true),
                const SizedBox(height: 12),
                _buildMainContent(theme, chatState, isUser, context),
              ],
            ),
      );
  }

  Widget _buildHeaderRow(ThemeData theme, bool isUser, {bool includeAvatar = false}) {
    return Row(
      children: [
        if (includeAvatar) ...[
          _buildAvatar(theme, isUser),
          const SizedBox(width: 12),
        ],
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
    );
  }

  Widget _buildMainContent(ThemeData theme, dynamic chatState, bool isUser, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.message.reasoning != null) _buildReasoning(theme, widget.message.reasoning!),
        if (_isEditing)
          _buildEditMode(theme)
        else if (widget.message.text.isEmpty && 
                 (widget.message.reasoning == null || widget.message.reasoning!.isEmpty) && 
                 chatState.isLoading && 
                 !isUser)
          if (chatState.researchStatus != null)
            _buildStatusIndicator(theme, chatState.researchStatus!)
          else
            const _TypingIndicator()
        else if (widget.message.text.isEmpty && 
                 (widget.message.reasoning == null || widget.message.reasoning!.isEmpty) && 
                 !chatState.isLoading && 
                 !isUser)
          const SizedBox.shrink()
        else
          MarkdownBody(
            data: widget.message.text,
            selectable: false,
            extensionSet: md.ExtensionSet(
              [
                LatexBlockSyntax(),
                ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
              ],
              [
                LatexInlineSyntax(),
                ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
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
                        type: 'document',
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
        ...ref.watch(pluginsProvider).expand((plugin) {
          final trigger = plugin.buildMessageActionTrigger(context, ref, widget.message);
          if (trigger != null) {
            return [const SizedBox(height: 12), trigger];
          }
          return <Widget>[];
        }),
        if (!_isEditing)
          Visibility(
            visible: !chatState.isLoading,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: isUser 
                ? Transform.translate(
                    offset: const Offset(-16, 0),
                    child: _buildActionMenu(context, ref, isUser),
                  )
                : _buildActionMenu(context, ref, isUser),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusIndicator(ThemeData theme, String status) {
    return Text(
      status,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
        height: 1.5,
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

    final List<Widget> actions = [
      _StaggeredAction(
        index: 0,
        child: _ActionButton(
          icon: Icons.copy_all_outlined,
          tooltip: 'Copy',
          onPressed: () {
            controller.copyToClipboard(widget.message.text);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
            );
          },
        ),
      ),
      if (isUser)
        _StaggeredAction(
          index: 1,
          child: _ActionButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: () => setState(() => _isEditing = true),
          ),
        )
      else
        _StaggeredAction(
          index: 1,
          child: _ActionButton(
            icon: Icons.refresh_outlined,
            tooltip: 'Regenerate',
            onPressed: () {
              final collectionId = ref.read(collectionProvider).activeCollection?.id;
              controller.regenerateResponse(widget.message.id, collectionId);
            },
          ),
        ),
      _StaggeredAction(
        index: 2,
        child: _ActionButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete',
          onPressed: () => controller.deleteMessage(widget.message.id),
        ),
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
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
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              _isReasoningExpanded = !_isReasoningExpanded;
              if (_isReasoningExpanded) {
                _userScrolledReasoning = false;
                _scrollReasoningToBottom();
              }
            }),
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
            secondChild: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                controller: _reasoningScrollController,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SelectableText(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
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

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = index * 0.2;
              double progress = (_controller.value - delay) % 1.0;
              if (progress < 0) progress += 1.0;
              
              double opacity = 0.2;
              if (progress < 0.5) {
                opacity = 0.2 + (0.6 * (progress / 0.5));
              } else {
                opacity = 0.8 - (0.6 * ((progress - 0.5) / 0.5));
              }

              return Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _StaggeredAction extends StatefulWidget {
  final Widget child;
  final int index;

  const _StaggeredAction({
    required this.child,
    required this.index,
  });

  @override
  State<_StaggeredAction> createState() => _StaggeredActionState();
}

class _StaggeredActionState extends State<_StaggeredAction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    ));

    const baseDelay = 0;
    const staggerDelay = 50;
    Future.delayed(Duration(milliseconds: baseDelay + (widget.index * staggerDelay)), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
