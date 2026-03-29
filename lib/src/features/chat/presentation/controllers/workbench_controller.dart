import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/services/portable_settings.dart';
class WorkbenchTab {
  final String id;
  final String title;
  final IconData icon;
  final String type;
  final bool isPermanent;
  final dynamic metadata;

  const WorkbenchTab({
    required this.id,
    required this.title,
    required this.icon,
    required this.type,
    this.isPermanent = false,
    this.metadata,
  });
}

class WorkbenchState {
// ... (panelRatio, isCollapsed, tabs - no changes needed here)
  final double panelRatio;
  final bool isCollapsed;
  final List<WorkbenchTab> tabs;
  final String? activeTabId;

  const WorkbenchState({
    this.panelRatio = 0.4,
    this.isCollapsed = true,
    this.tabs = const [
      WorkbenchTab(
        id: 'control_panel',
        title: 'Control Panel',
        icon: Icons.tune_rounded,
        type: 'controlPanel',
        isPermanent: true,
      ),
    ],
    this.activeTabId = 'control_panel',
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
    final prefs = await PortableSettings.getInstance();
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
    
    final prefs = await PortableSettings.getInstance();
    await prefs.setDouble('workbench_panelRatio', ratio);
  }

  Future<void> toggleCollapsed() async {
    final newState = !state.isCollapsed;
    state = state.copyWith(isCollapsed: newState);
    
    final prefs = await PortableSettings.getInstance();
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

  void navigateVersion(String tabId, int index) {
    final newTabs = state.tabs.map((t) {
      if (t.id == tabId && t.type == 'graph') {
        final List<dynamic>? versions = t.metadata?['versions'];
        if (versions != null && index >= 0 && index < versions.length) {
          const dataKey = 'schema';
          return WorkbenchTab(
            id: t.id,
            title: t.title,
            icon: t.icon,
            type: t.type,
            metadata: {
              ...t.metadata as Map<String, dynamic>,
              dataKey: versions[index],
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
    final tabToRemove = state.tabs.firstWhere((t) => t.id == id, orElse: () => const WorkbenchTab(id: '', title: '', icon: Icons.error, type: 'controlPanel'));
    if (tabToRemove.isPermanent) return; // Cannot remove permanent tabs

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
