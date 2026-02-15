import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WorkbenchTabType { graph, analysis, sandbox, document, diagram }

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
  final double panelWidth;
  final bool isCollapsed;
  final List<WorkbenchTab> tabs;
  final String? activeTabId;

  const WorkbenchState({
    this.panelWidth = 400.0,
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
    double? panelWidth,
    bool? isCollapsed,
    List<WorkbenchTab>? tabs,
    String? activeTabId,
    bool clearActiveTab = false,
  }) {
    return WorkbenchState(
      panelWidth: panelWidth ?? this.panelWidth,
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
    final panelWidth = prefs.getDouble('workbench_panelWidth') ?? 400.0;
    
    state = state.copyWith(
      isCollapsed: isCollapsed,
      panelWidth: panelWidth,
    );
  }

  Future<void> updateWidth(double width, {double? maxAvailableWidth}) async {
    if (width < 250) width = 250;
    if (maxAvailableWidth != null && width > maxAvailableWidth * 0.8) {
      width = maxAvailableWidth * 0.8;
    }
    state = state.copyWith(panelWidth: width);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('workbench_panelWidth', width);
  }

  Future<void> toggleCollapsed() async {
    final newState = !state.isCollapsed;
    state = state.copyWith(isCollapsed: newState);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('workbench_isCollapsed', newState);
  }

  void addTab(WorkbenchTab tab) {
    if (state.tabs.any((t) => t.id == tab.id)) {
      if (tab.metadata != null) {
        updateTabMetadata(tab.id, tab.metadata);
      }
      selectTab(tab.id);
      return;
    }
    state = state.copyWith(
      tabs: [...state.tabs, tab],
      activeTabId: tab.id,
      isCollapsed: false,
    );
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
