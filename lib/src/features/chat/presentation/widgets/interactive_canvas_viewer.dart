import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_svg/flutter_html_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InteractiveCanvasViewer extends ConsumerWidget {
  final String htmlContent;

  const InteractiveCanvasViewer({super.key, required this.htmlContent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SelectionArea(
              child: Html(
                data: htmlContent,
                onLinkTap: (url, attributes, element) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Action triggered: $url')),
                  );
                },
                style: {
                  "body": Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    color: Colors.white,
                    fontSize: FontSize(16),
                    lineHeight: const LineHeight(1.6),
                  ),
                  "h1": Style(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  "h2": Style(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  "h3": Style(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  "a": Style(
                    color: theme.colorScheme.primary,
                    textDecoration: TextDecoration.none,
                    fontWeight: FontWeight.bold,
                  ),
                  ".accent": Style(color: theme.colorScheme.primary),
                  "table": Style(
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    padding: HtmlPaddings.all(12),
                  ),
                  "th": Style(
                    padding: HtmlPaddings.all(8),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    fontWeight: FontWeight.bold,
                  ),
                  "td": Style(
                    padding: HtmlPaddings.all(8),
                    border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
                  ),
                  "pre": Style(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    padding: HtmlPaddings.all(12),
                    fontFamily: 'monospace',
                  ),
                  "code": Style(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
                    fontFamily: 'monospace',
                  ),
                },
                extensions: const [
                  SvgHtmlExtension(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
