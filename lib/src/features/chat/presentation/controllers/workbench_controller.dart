import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WorkbenchTabType { graph, analysis, sandbox, document, diagram, visualization }

class WorkbenchTab {
  final String id;
  final String title;
  final IconData icon;
  final WorkbenchTabType type;
  final dynamic metadata;

  const WorkbenchTab({
    required this.id,
    required this.title,
    required this.icon,
    required this.type,
    this.metadata,
  });
}

class WorkbenchState {
  final double panelRatio;
  final bool isCollapsed;
  final List<WorkbenchTab> tabs;
  final String? activeTabId;

  const WorkbenchState({
    this.panelRatio = 0.4,
    this.isCollapsed = true,
    this.tabs = const [],
    this.activeTabId,
  });

  WorkbenchTab? get activeTab {
    if (activeTabId == null || tabs.isEmpty) return null;
    try {
      return tabs.firstWhere((t) => t.id == activeTabId);
    } catch (_) {
      return null;
    }
  }

  WorkbenchState copyWith({
    double? panelRatio,
    bool? isCollapsed,
    List<WorkbenchTab>? tabs,
    String? activeTabId,
    bool clearActiveTab = false,
  }) {
    return WorkbenchState(
      panelRatio: panelRatio ?? this.panelRatio,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      tabs: tabs ?? this.tabs,
      activeTabId: clearActiveTab ? null : (activeTabId ?? this.activeTabId),
    );
  }
}

class WorkbenchController extends StateNotifier<WorkbenchState> {
  WorkbenchController() : super(const WorkbenchState()) {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final isCollapsed = prefs.getBool('workbench_isCollapsed') ?? true;
    final panelRatio = prefs.getDouble('workbench_panelRatio') ?? 0.4;
    
    state = state.copyWith(
      isCollapsed: isCollapsed,
      panelRatio: panelRatio,
    );
  }

  Future<void> updateRatio(double ratio) async {
    // Clamp ratio between 0.2 and 0.8 to preserve chat visibility
    if (ratio < 0.2) ratio = 0.2;
    if (ratio > 0.8) ratio = 0.8;
    
    state = state.copyWith(panelRatio: ratio);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('workbench_panelRatio', ratio);
  }

  Future<void> toggleCollapsed() async {
    final newState = !state.isCollapsed;
    state = state.copyWith(isCollapsed: newState);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('workbench_isCollapsed', newState);
  }

  void addTab(WorkbenchTab tab) {
    // 1. Check for exactly the same ID (e.g. reopening a document)
    if (state.tabs.any((t) => t.id == tab.id)) {
      if (tab.metadata != null) {
        updateTabMetadata(tab.id, tab.metadata);
      }
      selectTab(tab.id);
      return;
    }

    // 2. Specialized Logic for Visualizations: Match by Title for Versioning
    if (tab.type == WorkbenchTabType.visualization) {
      final String? incomingSchema = tab.metadata?['schema'];
      if (incomingSchema != null) {
        // Try to find a tab with the same title
        final existingTabIndex = state.tabs.indexWhere(
          (t) => t.type == WorkbenchTabType.visualization && t.title == tab.title
        );

        if (existingTabIndex != -1) {
          final existingTab = state.tabs[existingTabIndex];
          final List<dynamic> versions = List.from(existingTab.metadata?['versions'] ?? [existingTab.metadata?['schema']]);
          
          // Check if this exact schema is already in versions to avoid duplicates on rebuilds
          if (!versions.contains(incomingSchema)) {
            versions.add(incomingSchema);
          }

          final updatedTab = WorkbenchTab(
            id: existingTab.id,
            title: existingTab.title,
            icon: existingTab.icon,
            type: existingTab.type,
            metadata: {
              'schema': incomingSchema, // Current active schema
              'versions': versions,
              'currentIndex': versions.length - 1,
            },
          );

          final newTabs = List<WorkbenchTab>.from(state.tabs);
          newTabs[existingTabIndex] = updatedTab;

          state = state.copyWith(
            tabs: newTabs,
            activeTabId: existingTab.id,
            isCollapsed: false,
          );
          return;
        }
      }
      
      // If it's a new visualization, initialize the versioning structure
      final newTab = WorkbenchTab(
        id: tab.id,
        title: tab.title,
        icon: tab.icon,
        type: tab.type,
        metadata: {
          'schema': tab.metadata?['schema'],
          'versions': [tab.metadata?['schema']],
          'currentIndex': 0,
        },
      );
      state = state.copyWith(
        tabs: [...state.tabs, newTab],
        activeTabId: tab.id,
        isCollapsed: false,
      );
      return;
    }

    // 3. Default behavior for other tab types
    state = state.copyWith(
      tabs: [...state.tabs, tab],
      activeTabId: tab.id,
      isCollapsed: false,
    );
  }

  void navigateVersion(String tabId, int index) {
    final newTabs = state.tabs.map((t) {
      if (t.id == tabId && t.type == WorkbenchTabType.visualization) {
        final List<dynamic>? versions = t.metadata?['versions'];
        if (versions != null && index >= 0 && index < versions.length) {
          return WorkbenchTab(
            id: t.id,
            title: t.title,
            icon: t.icon,
            type: t.type,
            metadata: {
              ...t.metadata as Map<String, dynamic>,
              'schema': versions[index],
              'currentIndex': index,
            },
          );
        }
      }
      return t;
    }).toList();
    state = state.copyWith(tabs: newTabs);
  }

  void updateTabMetadata(String id, dynamic metadata) {
    final newTabs = state.tabs.map((t) {
      if (t.id == id) {
        return WorkbenchTab(
          id: t.id,
          title: t.title,
          icon: t.icon,
          type: t.type,
          metadata: metadata,
        );
      }
      return t;
    }).toList();
    state = state.copyWith(tabs: newTabs);
  }

  void removeTab(String id) {
    final newTabs = state.tabs.where((t) => t.id != id).toList();
    String? newActiveId = state.activeTabId;
    
    if (state.activeTabId == id) {
      newActiveId = newTabs.isNotEmpty ? newTabs.last.id : null;
    }
    
    state = state.copyWith(
      tabs: newTabs,
      activeTabId: newActiveId,
      clearActiveTab: newActiveId == null,
    );
  }

  void selectTab(String id) {
    state = state.copyWith(activeTabId: id, isCollapsed: false);
  }
}

final workbenchProvider = StateNotifierProvider<WorkbenchController, WorkbenchState>((ref) {
  return WorkbenchController();
});
