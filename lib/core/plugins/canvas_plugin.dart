import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agent_plugin.dart';
import '../models/ai_models.dart';
import '../../src/features/chat/domain/entities/message.dart';
import '../../src/features/chat/presentation/controllers/settings_controller.dart';
import '../../src/features/chat/presentation/controllers/workbench_controller.dart';
import '../../src/features/orchestrator/domain/interactive_canvas_orchestrator.dart';

class CanvasPlugin extends AgentPlugin {
  final InteractiveCanvasOrchestrator _orchestrator;

  CanvasPlugin(this._orchestrator);

  @override
  String get name => 'Interactive Canvas';

  @override
  String get toolName => 'delegate_to_interactive_canvas';

  @override
  ToolDefinition get toolDefinition => ToolDefinition(
    function: FunctionDefinition(
      name: toolName,
      description: 'Useful for generating highly custom static visual representations of research data using HTML/CSS/SVG. Use this when a standard chart is not enough and you want to create a rich, structured visual display (e.g., custom timelines, multi-column reports, SVG infographics).',
      parameters: {
        'type': 'object',
        'properties': {
          'canvasGoal': {
            'type': 'string',
            'description': 'Describe exactly what should be rendered in the canvas (e.g., "A visual SVG of the solar system", "A formatted HTML medical report with custom styling").',
          },
          'indices': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'The indices of the chunks [[Chunk X]] containing the data to visualize.',
          },
        },
        'required': ['canvasGoal', 'indices'],
      },
    ),
  );

  @override
  String get mandate => '**CRITICAL MANDATE**: The user has requested a custom visual display component. You MUST call `query_knowledge_base` first. After searching, you MUST call `delegate_to_interactive_canvas` to build the static visual component using HTML/SVG.';

  @override
  String getStatusMessage(Map<String, dynamic> toolArgs) {
    final goal = toolArgs['canvasGoal'] as String? ?? 'component';
    return 'Designing visual layout for "$goal"...';
  }

  @override
  bool isEnabled(SettingsState settings) => settings.interactiveCanvasMode != InteractiveCanvasMode.off;

  @override
  Future<PluginResult> execute({
    required Map<String, dynamic> toolArgs,
    required String userQuery,
    required String fullContext,
    required ChunkRegistry registry,
    Map<String, dynamic>? currentTabMetadata,
  }) async {
    final indices = List<int>.from(toolArgs['indices'] ?? []);
    final goal = toolArgs['canvasGoal'] as String? ?? 'Generate interactive canvas';
    final package = InteractiveCanvasPackage(indices: indices, canvasGoal: goal);

    final result = await _orchestrator.generateCanvas(
      package: package,
      registry: registry,
      fullContext: fullContext,
    );

    return PluginResult(
      metadataToPersist: {
        'canvas_html': result.htmlContent,
      },
      resultData: result.htmlContent,
    );
  }

  @override
  String getSynthesisInjection(PluginResult result) {
    if (result.resultData == null) return '';
    return '### INTERACTIVE_CANVAS\n${result.resultData}\n(Note: This interactive HTML/SVG component has been displayed in a separate tab. Acknowledge this in your response.)\n\n';
  }

  @override
  void onResult(PluginResult result, String messageId, Ref ref) {
    final htmlContent = result.resultData as String?;
    if (htmlContent == null) return;

    ref.read(workbenchProvider.notifier).addTab(
      WorkbenchTab(
        id: 'canvas_$messageId',
        title: 'Interactive Canvas',
        icon: Icons.auto_awesome_mosaic_rounded,
        type: WorkbenchTabType.interactiveCanvas,
        metadata: {
          'htmlContent': htmlContent,
        },
      ),
    );
  }

  @override
  Widget? buildMessageActionTrigger(BuildContext context, WidgetRef ref, Message message) {
    final htmlContent = message.metadata?['canvas_html'] as String?;
    if (htmlContent == null) return null;

    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: () {
        ref.read(workbenchProvider.notifier).addTab(
          WorkbenchTab(
            id: 'canvas_${message.id}',
            title: 'Canvas',
            icon: Icons.auto_awesome_mosaic_rounded,
            type: WorkbenchTabType.interactiveCanvas,
            metadata: {
              'htmlContent': htmlContent,
            },
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
      child: const Text('View Canvas'),
    );
  }
}
