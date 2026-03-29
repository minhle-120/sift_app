import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/workbench_controller.dart';
import '../controllers/settings_controller.dart';
import '../../../knowledge/presentation/widgets/document_viewer.dart';
import 'control_panel.dart';
import '../../../../../core/plugins/plugins_provider.dart';

class WorkbenchPanel extends ConsumerWidget {
  const WorkbenchPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workbench = ref.watch(workbenchProvider);
    final settings = ref.watch(settingsProvider);
    
    
    // Filter tabs for Mobile Lite Mode (internal AI)
    final filteredTabs = workbench.tabs.where((tab) {
      if (settings.isMobileInternal && tab.type == 'controlPanel') {
        return false;
      }
      return true;
    }).toList();
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          if (filteredTabs.isNotEmpty) _buildTabBar(ref, workbench, filteredTabs, theme),
          Expanded(
            child: _buildContent(context, ref, workbench.activeTab, settings.isMobileInternal, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(WidgetRef ref, WorkbenchState state, List<WorkbenchTab> tabs, ThemeData theme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isActive = tab.id == state.activeTabId;

          return InkWell(
            onTap: () => ref.read(workbenchProvider.notifier).selectTab(tab.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? theme.colorScheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                   Icon(tab.icon, size: 16, color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                   const SizedBox(width: 8),
                   Text(
                     tab.title,
                     style: theme.textTheme.labelMedium?.copyWith(
                       color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                       fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                     ),
                   ),
                   const SizedBox(width: 8),
                   if (!tab.isPermanent)
                     GestureDetector(
                       onTap: () => ref.read(workbenchProvider.notifier).removeTab(tab.id),
                       child: Icon(Icons.close, size: 14, color: theme.colorScheme.onSurfaceVariant),
                     ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, WorkbenchTab? tab, bool isMobileInternal, ThemeData theme) {
    if (tab == null || (isMobileInternal && tab.type == 'controlPanel')) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub_outlined, size: 48, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No active workspace',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Try plugins first
    final plugins = ref.watch(pluginsProvider);
    for (final plugin in plugins) {
       final widget = plugin.buildWorkbenchTab(context, tab);
       if (widget != null) {
         return widget;
       }
    }

    // Fallback to core standard tabs
    if (tab.type == 'controlPanel') {
      return const ControlPanel();
    } else if (tab.type == 'document') {
      final meta = tab.metadata as Map<String, dynamic>?;
      final docId = meta?['documentId'] as int?;
      final chunkIndex = meta?['chunkIndex'] as int?;
      
      if (docId != null) {
        return DocumentViewer(
          key: ValueKey('doc_$docId'),
          documentId: docId,
          initialChunkIndex: chunkIndex,
        );
      }
    }
    
    return _buildPlaceholderContent(tab.type, theme);
  }

  Widget _buildPlaceholderContent(String type, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 48, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            '${type.toUpperCase()} View Coming Soon',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
