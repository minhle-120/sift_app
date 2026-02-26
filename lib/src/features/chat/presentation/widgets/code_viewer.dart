import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntax_highlight/syntax_highlight.dart';
import 'package:sift_app/core/theme/sift_theme.dart';

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

    final String normalizedLanguage = _mapLanguage(language);

    Widget codeContent;
    try {
      final highlighter = Highlighter(
        language: normalizedLanguage,
        theme: isDark ? SiftTheme.darkCodeTheme : SiftTheme.lightCodeTheme,
      );
      codeContent = Text.rich(
        highlighter.highlight(code),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          height: 1.3,
        ),
      );
    } catch (e) {
      codeContent = Text(
        code,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          height: 1.3,
          color: isDark ? Colors.grey[300] : Colors.grey[800],
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(context, theme, isDark),
        Expanded(
          child: Container(
            width: double.infinity,
            color: isDark ? Colors.black : Colors.white,
            child: SelectionArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: codeContent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _mapLanguage(String lang) {
    final l = lang.toLowerCase().trim();
    if (l == 'py' || l == 'python3') return 'python';
    if (l == 'js' || l == 'node') return 'javascript';
    if (l == 'ts' || l == 'tsx') return 'typescript';
    if (l == 'md') return 'markdown';
    if (l == 'yml') return 'yaml';
    if (l == 'rb') return 'ruby';
    if (l == 'sh' || l == 'bash') return 'plaintext';
    return l.isEmpty ? 'plaintext' : l;
  }

  Widget _buildToolbar(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      height: 32, // More subtle toolbar
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            language.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
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
