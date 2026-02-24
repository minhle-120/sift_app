import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter_highlighter/themes/atom-one-light.dart';

class CodeViewer extends StatelessWidget {
  final String code;
  final String language;

  const CodeViewer({
    super.key,
    required this.code,
    this.language = 'plaintext',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        _buildToolbar(context, theme, isDark),
        Expanded(
          child: Container(
            width: double.infinity,
            color: isDark ? const Color(0xFF282C34) : const Color(0xFFF0F0F0),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HighlightView(
                code,
                language: language.isEmpty ? 'plaintext' : language,
                theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            language.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          _CopyButton(code: code),
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

    return TextButton.icon(
      onPressed: () {
        Clipboard.setData(ClipboardData(text: widget.code));
        setState(() => _copied = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      },
      icon: Icon(
        _copied ? Icons.check : Icons.content_copy,
        size: 14,
        color: _copied ? Colors.green : theme.colorScheme.primary,
      ),
      label: Text(
        _copied ? 'Copied' : 'Copy',
        style: TextStyle(
          fontSize: 12,
          color: _copied ? Colors.green : theme.colorScheme.primary,
        ),
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
