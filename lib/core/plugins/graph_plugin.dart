import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agent_plugin.dart';
import '../models/ai_models.dart';
import '../../src/features/chat/domain/entities/message.dart';
import '../../src/features/chat/presentation/controllers/settings_controller.dart';
import '../../src/features/chat/presentation/controllers/workbench_controller.dart';
import '../../src/features/orchestrator/domain/graph_generator_orchestrator.dart';
import '../../src/features/chat/presentation/widgets/graph_viewer.dart';
import 'dart:convert';

class GraphPlugin extends AgentPlugin {
  final GraphGeneratorOrchestrator _orchestrator;

  GraphPlugin(this._orchestrator);

  @override
  String get id => 'graph';

  @override
  String get name => 'Graph';

  @override
  IconData get icon => Icons.hub_rounded;

  @override
  String get toolName => 'delegate_to_graph_generator';

  @override
  ToolDefinition get toolDefinition => ToolDefinition(
    function: FunctionDefinition(
      name: toolName,
      description: 'Delegate to a graph drawer when you find complex relationships, hierarchies, or comparative data that should be visualized as an interactive graph.',
      parameters: {
        'type': 'object',
        'properties': {
          'graphGoal': {
            'type': 'string',
            'description': 'Describe exactly what should be graphed.',
          },
          'indices': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'The indices of the chunks [[Chunk X]] containing the data to visualize.',
          },
        },
        'required': ['graphGoal', 'indices'],
      },
    ),
  );

  @override
  String get mandate => '**CRITICAL MANDATE**: The user has requested a graph. You MUST call `query_knowledge_base` first to gather data. After searching, you MUST call `delegate_to_graph_generator` if you find ANY relevant data to visualize, even if it is simple. Prioritize finding a visual angle for your research.';

  @override
  String getStatusMessage(Map<String, dynamic> toolArgs) {
    final goal = toolArgs['graphGoal'] as String? ?? 'data';
    return 'Generating graph for "$goal"...';
  }

  @override
  bool isEnabled(SettingsState settings) => settings.pluginModes[id] != PluginMode.off;

  @override
  Future<PluginResult> execute({
    required Map<String, dynamic> toolArgs,
    required String userQuery,
    required String fullContext,
    required ChunkRegistry registry,
  }) async {
    final indices = List<int>.from(toolArgs['indices'] ?? []);
    final goal = toolArgs['graphGoal'] as String? ?? 'Generate graph';
    final package = GraphPackage(indices: indices, graphGoal: goal);

    final result = await _orchestrator.generateGraph(
      package: package,
      registry: registry,
      fullContext: fullContext,
    );

    return PluginResult(
      metadataToPersist: {'graph_schema': result.schema},
      resultData: result.schema,
    );
  }

  @override
  ArtifactContent getArtifactContent(PluginResult result) {
    final schema = result.resultData as String?;
    if (schema == null || schema.isEmpty) {
      return ArtifactContent(type: 'RENDERED_GRAPH', body: 'No graph schema generated.');
    }

    return ArtifactContent(
      type: 'RENDERED_GRAPH',
      body: schema,
    );
  }

  @override
  void onResult(PluginResult result, String messageId, Ref ref) {
    final schemaStr = result.resultData as String?;
    if (schemaStr == null) return;

    String? parsedTitle;
    try {
      final Map<String, dynamic> schema = jsonDecode(schemaStr);
      parsedTitle = schema['title'] as String?;
    } catch (_) {}

    final wb = ref.read(workbenchProvider);
    final existingIndex = wb.tabs.indexWhere((t) => t.type == 'graph' && t.title == parsedTitle);

    List<dynamic> versions = [schemaStr];
    String targetId = 'graph_$messageId';

    if (existingIndex != -1) {
      final existingTab = wb.tabs[existingIndex];
      targetId = existingTab.id;
      versions = List.from(existingTab.metadata?['versions'] ?? [existingTab.metadata?['schema']]);
      if (!versions.contains(schemaStr)) {
        versions.add(schemaStr);
      }
    }

    ref.read(workbenchProvider.notifier).addTab(
      WorkbenchTab(
        id: targetId,
        title: parsedTitle ?? 'Graph',
        icon: Icons.hub_rounded,
        type: 'graph',
        metadata: {
          'schema': schemaStr,
          'versions': versions,
          'currentIndex': versions.length - 1,
        },
      ),
    );
  }

  @override
  Widget? buildMessageActionTrigger(BuildContext context, WidgetRef ref, Message message) {
    final schemaStr = message.metadata?['graph_schema'] as String?;
    if (schemaStr == null) return null;

    final theme = Theme.of(context);
    String label = 'View Interactive Graph';
    String tabTitle = 'Graph';

    try {
      final Map<String, dynamic> schema = jsonDecode(schemaStr);
      final title = schema['title'] as String?;
      if (title != null && title.isNotEmpty) {
        label = 'View $title';
        tabTitle = title;
      }
    } catch (_) {}

    return ElevatedButton(
      onPressed: () {
        ref.read(workbenchProvider.notifier).addTab(
          WorkbenchTab(
            id: 'graph_${message.id}',
            title: tabTitle,
            icon: Icons.hub_rounded,
            type: 'graph',
            metadata: {'schema': schemaStr},
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      child: Text(label),
    );
  }

  @override
  Widget? buildWorkbenchTab(BuildContext context, WorkbenchTab tab) {
    if (tab.type != 'graph') return null;
    
    final meta = tab.metadata as Map<String, dynamic>?;
    var schemaStr = meta?['schema'] as String?;
    
    if (schemaStr != null) {
      if (schemaStr.contains('```')) {
        schemaStr = schemaStr.replaceAll(RegExp(r'```json|```'), '').trim();
      }

      try {
        final schema = jsonDecode(schemaStr) as Map<String, dynamic>;
        return GraphViewer(
          key: ValueKey('${tab.id}_${meta?['currentIndex'] ?? 0}'),
          schema: schema,
        );
      } catch (e) {
        return Center(child: Text('Invalid graph data: $e'));
      }
    }
    return null;
  }
}
