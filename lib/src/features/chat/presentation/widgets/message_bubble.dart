import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../domain/entities/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
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
                  selectable: true,
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
                    ),
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
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
  CitationSyntax() : super(r'\[{1,2}([\d\s,]+)\]{1,2}');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final rawIndex = match.group(1);
    final element = md.Element('citation', [md.Text(rawIndex!)]);
    parser.addNode(element);
    return true;
  }
}

class CitationBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  CitationBuilder({required this.context});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final rawContent = element.textContent;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        rawContent,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
