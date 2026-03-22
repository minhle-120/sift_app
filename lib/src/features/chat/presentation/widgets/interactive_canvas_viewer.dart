import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_svg/flutter_html_svg.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InteractiveCanvasViewer extends ConsumerWidget {
  final String htmlContent;

  const InteractiveCanvasViewer({super.key, required this.htmlContent});

  String _processHtml(String html) {
    // 1. Strip all <a> tags to enforce the "No Interactivity" rule
    String processed =
        html.replaceAll(RegExp(r'<a[^>]*>'), '').replaceAll('</a>', '');

    // 2. GLOBAL CSS SANITIZATION: Strip banned properties from <style> blocks and inline styles
    processed = processed
        .replaceAll(
            RegExp(r'display\s*:\s*(flex|grid|block|inline-block)[^;]*;?',
                caseSensitive: false),
            '')
        .replaceAll(
            RegExp(r'overflow(-[xy])?\s*:\s*[^;]*;?', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'box-sizing\s*:\s*[^;]*;?', caseSensitive: false), '')
        .replaceAll(RegExp(r'position\s*:\s*[^;]*;?', caseSensitive: false), '')
        .replaceAll(RegExp(r'float\s*:\s*[^;]*;?', caseSensitive: false), '');

    // 3. PERCENTAGE BUG FIX: flutter_html_table incorrectly parses "100%" as "100.0 pixels"
    // Strip all percentage-based widths to let the engine auto-size columns based on intrinsic content.
    processed = processed
        .replaceAll(
            RegExp(r'''width\s*=\s*["']\d+%["']''', caseSensitive: false), '')
        .replaceAll(RegExp(r'width\s*:\s*\d+%\s*;?', caseSensitive: false), '');

    return processed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = (constraints.maxWidth - 32).clamp(0.0, 800.0);
          final processedContent = _processHtml(htmlContent);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Center(
              child: SizedBox(
                width: availableWidth,
                child: Html(
                  data: processedContent,
                  style: {
                    "body": Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      color: Colors.white,
                      fontSize: FontSize(16),
                      lineHeight: const LineHeight(1.6),
                    ),
                    "h1": Style(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    "h2": Style(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    "h3": Style(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    ".accent": Style(color: theme.colorScheme.primary),
                    "table": Style(
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      margin: Margins.only(bottom: 24),
                    ),
                    "th": Style(
                      padding: HtmlPaddings.all(12),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      fontWeight: FontWeight.bold,
                      verticalAlign: VerticalAlign.bottom,
                      fontSize: FontSize(12),
                      color: const Color(0xFF938F99),
                    ),
                    "td": Style(
                      padding: HtmlPaddings.all(12),
                      verticalAlign: VerticalAlign.top,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    "pre": Style(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      padding: HtmlPaddings.all(12),
                      fontFamily: 'monospace',
                    ),
                    "code": Style(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      padding:
                          HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
                      fontFamily: 'monospace',
                    ),
                  },
                  extensions: const [
                    SvgHtmlExtension(),
                    TableHtmlExtension(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
