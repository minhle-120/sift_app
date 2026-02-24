import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter_highlighter/themes/atom-one-light.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  CodeElementBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Extract language from class attribute (e.g., class="language-dart")
    String language = '';
    if (element.attributes.containsKey('class')) {
      final className = element.attributes['class']!;
      if (className.startsWith('language-')) {
        language = className.substring(9);
      }
    }

    final String code = element.textContent.trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282C34) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: HighlightView(
              code,
              language: language.isEmpty ? 'plaintext' : language,
              theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          if (language.isNotEmpty)
            Positioned(
              top: 8,
              left: 12,
              child: Text(
                language.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: _CopyButton(code: code),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String code;
  const _CopyButton({required this.code});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _copied ? Icons.check : Icons.content_copy,
          key: ValueKey(_copied),
          size: 16,
          color: _copied 
            ? theme.colorScheme.primary 
            : (isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
      ),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: widget.code));
        setState(() => _copied = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      },
      tooltip: _copied ? 'Copied!' : 'Copy code',
      visualDensity: VisualDensity.compact,
    );
  }
}
