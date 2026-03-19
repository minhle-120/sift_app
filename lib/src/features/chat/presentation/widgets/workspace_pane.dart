import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/models/ai_models.dart';
import '../controllers/workbench_controller.dart';
import '../controllers/settings_controller.dart';
import '../../../knowledge/presentation/widgets/document_viewer.dart';
import 'chart_viewer.dart';
import 'code_viewer.dart';
import 'flashcard_viewer.dart';
import 'control_panel.dart';
import 'dart:convert';

class WorkbenchPanel extends ConsumerWidget {
  const WorkbenchPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workbench = ref.watch(workbenchProvider);
    final settings = ref.watch(settingsProvider);
    
    // Filter tabs for Mobile Lite Mode (internal AI)
    final filteredTabs = workbench.tabs.where((tab) {
      if (settings.isMobileInternal && tab.type == WorkbenchTabType.controlPanel) {
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
            child: _buildContent(workbench.activeTab, settings.isMobileInternal, theme),
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

  Widget _buildContent(WorkbenchTab? tab, bool isMobileInternal, ThemeData theme) {
    if (tab == null || (isMobileInternal && tab.type == WorkbenchTabType.controlPanel)) {
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

    if (tab.type == WorkbenchTabType.document) {
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
    } else if (tab.type == WorkbenchTabType.chart) {
      final meta = tab.metadata as Map<String, dynamic>?;
      var schemaStr = meta?['schema'] as String?;
      
      if (schemaStr != null) {
        // Robustness: Strip markdown backticks if they persisted
        if (schemaStr.contains('```')) {
          schemaStr = schemaStr.replaceAll(RegExp(r'```json|```'), '').trim();
        }

        try {
          final schema = jsonDecode(schemaStr) as Map<String, dynamic>;
          return ChartViewer(
            key: ValueKey('${tab.id}_${meta?['currentIndex'] ?? 0}'),
            schema: schema,
          );
        } catch (e) {
          return Center(child: Text('Invalid chart data: $e'));
        }
      }
    } else if (tab.type == WorkbenchTabType.code) {
      final meta = tab.metadata as Map<String, dynamic>?;
      final code = meta?['code'] as String?;
      final language = meta?['language'] as String? ?? 'dart';
      
      if (code != null) {
        return CodeViewer(
          key: ValueKey(tab.id),
          code: code,
          language: language,
        );
      }
    } else if (tab.type == WorkbenchTabType.flashcards) {
      final meta = tab.metadata as Map<String, dynamic>?;
      final cardsRaw = meta?['cards'] as List<dynamic>?;
      
      if (cardsRaw != null) {
        final cards = cardsRaw.map((c) => Flashcard.fromJson(c as Map<String, dynamic>)).toList();
        return FlashcardViewer(
          key: ValueKey(tab.id),
          cards: cards,
        );
      }
    } else if (tab.type == WorkbenchTabType.controlPanel) {
      return const ControlPanel();
    }
    
    return _buildPlaceholderContent(tab.type, theme);
  }

  Widget _buildPlaceholderContent(WorkbenchTabType type, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 48, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            '${type.name.toUpperCase()} View Coming Soon',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
