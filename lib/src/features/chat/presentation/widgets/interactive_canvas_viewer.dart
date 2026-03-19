import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_svg/flutter_html_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/workbench_controller.dart';

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
          _buildVersionNavigator(context, ref),
        ],
      ),
    );
  }

  Widget _buildVersionNavigator(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workbench = ref.watch(workbenchProvider);
    final activeTab = workbench.activeTab;
    
    if (activeTab == null || activeTab.type != WorkbenchTabType.interactiveCanvas) {
      return const SizedBox.shrink();
    }

    final metadata = activeTab.metadata as Map<String, dynamic>?;
    final versions = metadata?['versions'] as List<dynamic>?;
    final currentIndex = metadata?['currentIndex'] as int? ?? 0;

    if (versions == null || versions.length <= 1) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: currentIndex > 0 
                    ? () => ref.read(workbenchProvider.notifier).navigateVersion(activeTab.id, currentIndex - 1)
                    : null,
                  tooltip: 'Previous Version',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Version ${currentIndex + 1} of ${versions.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: currentIndex < versions.length - 1
                    ? () => ref.read(workbenchProvider.notifier).navigateVersion(activeTab.id, currentIndex + 1)
                    : null,
                  tooltip: 'Next Version',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
