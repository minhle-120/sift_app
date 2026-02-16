import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../domain/entities/message.dart';
import '../controllers/workbench_controller.dart';

class MessageBubble extends ConsumerWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == MessageRole.user;
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
                Text(
                  isUser ? 'You' : 'Sift',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isUser ? theme.colorScheme.primary : theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                if (message.reasoning != null) _buildReasoning(theme, message.reasoning!),
                MarkdownBody(
                  data: message.text,
                  selectable: false,
                  extensionSet: md.ExtensionSet(
                    [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                    [
                      ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                      CitationSyntax(),
                    ],
                  ),
                  builders: {
                    'citation': CitationBuilder(
                      context: context,
                      citations: message.citations,
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
                  styleSheet: MarkdownStyleSheet(
                    p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
                if (message.metadata?['visual_schema'] != null) ...[
                  const SizedBox(height: 12),
                  _buildVisualTrigger(context, ref, theme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualTrigger(BuildContext context, WidgetRef ref, ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: () {
        final schema = message.metadata?['visual_schema'] as String;
        
        ref.read(workbenchProvider.notifier).addTab(
          WorkbenchTab(
            id: 'viz_${message.id}',
            title: 'Visualization',
            icon: Icons.hub_outlined,
            type: WorkbenchTabType.visualization,
            metadata: {'schema': schema},
          ),
        );
      },
      icon: const Icon(Icons.hub_outlined, size: 18),
      label: const Text('View Interactive Graph'),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text('Reasoning', style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }
}

class CitationSyntax extends md.InlineSyntax {
  CitationSyntax() : super(r'\[{1,2}(?:Chunk\s+)?(\d+)\]{1,2}');

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

    return Tooltip(
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
          margin: const EdgeInsets.symmetric(horizontal: 2),
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
    );
  }
}
