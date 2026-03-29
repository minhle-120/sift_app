import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agent_plugin.dart';
import '../models/ai_models.dart';
import '../../src/features/chat/domain/entities/message.dart';
import '../../src/features/chat/presentation/controllers/settings_controller.dart';
import '../../src/features/chat/presentation/controllers/workbench_controller.dart';
import '../../src/features/orchestrator/domain/code_orchestrator.dart';
import '../../src/features/chat/presentation/widgets/code_viewer.dart';

class CodePlugin extends AgentPlugin {
  final CodeOrchestrator _orchestrator;

  CodePlugin(this._orchestrator);

  @override
  String get id => 'code';

  @override
  String get name => 'Code';
  
  @override
  IconData get icon => Icons.terminal_rounded;

  @override
  String get toolName => 'delegate_to_coder';

  @override
  ToolDefinition get toolDefinition => ToolDefinition(
    function: FunctionDefinition(
      name: toolName,
      description: 'Delegate to a code specialist when the user wants to generate code, scripts, or technical implementations based on the research.',
      parameters: {
        'type': 'object',
        'properties': {
          'codingGoal': {
            'type': 'string',
            'description': 'Describe exactly what needs to be coded.',
          },
          'indices': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'The indices of the chunks [[Chunk X]] containing reference material.',
          },
        },
        'required': ['codingGoal', 'indices'],
      },
    ),
  );

  @override
  String get mandate => '**CRITICAL MANDATE**: The user has requested to write or modify code. You MUST call `query_knowledge_base` first to gather context. After searching, you MUST call `delegate_to_coder` if the user wants code generation, script writing, or technical implementation. Do NOT write the code yourself; delegate it to the code specialist.';

  @override
  String getStatusMessage(Map<String, dynamic> toolArgs) {
    final goal = toolArgs['codingGoal'] as String? ?? 'task';
    return 'Generating code for "$goal"...';
  }

  @override
  bool isEnabled(SettingsState settings) => settings.pluginModes[id] != PluginMode.off;

  @override
  Future<PluginResult> execute({
    required Map<String, dynamic> toolArgs,
    required String userQuery,
    required String fullContext,
    required ChunkRegistry registry,
    Map<String, dynamic>? currentTabMetadata,
  }) async {
    final indices = List<int>.from(toolArgs['indices'] ?? []);
    final goal = toolArgs['codingGoal'] as String? ?? 'Write code';
    final package = CodePackage(indices: indices, codingGoal: goal);

    final result = await _orchestrator.generateCode(
      package: package,
      registry: registry,
      fullContext: fullContext,
      currentCode: currentTabMetadata?['code'],
      currentCodeTitle: currentTabMetadata?['title'], // CodeOrchestrator uses currentCodeTitle
    );

    return PluginResult(
      metadataToPersist: {
        'code_snippet': result.codeSnippet,
        if (result.title != null) 'code_title': result.title,
      },
      resultData: result,
    );
  }

  @override
  String getSynthesisInjection(PluginResult result) {
    final data = result.resultData as CodeResult?;
    if (data == null || data.codeSnippet.isEmpty) return '';
    return '### WRITTEN_CODE\n${data.codeSnippet}\n(Note: This code has already been displayed to the user. USE THIS CODE TO ANSWER THE QUERY. Start answer with "Here is the explanation of the code...")\n\n';
  }

  @override
  void onResult(PluginResult result, String messageId, Ref ref) {
    final data = result.resultData as CodeResult?;
    if (data == null) return;

    ref.read(workbenchProvider.notifier).addTab(
      WorkbenchTab(
        id: 'code_$messageId',
        title: data.title ?? 'Generated Code',
        icon: Icons.code_rounded,
        type: 'code',
        metadata: {
          'code': data.codeSnippet,
          'language': data.language,
        },
      ),
    );
  }

  String _detectLanguage(String code) {
    final lowerCode = code.toLowerCase();
    if (lowerCode.contains('import') && lowerCode.contains('package:')) return 'dart';
    if (lowerCode.contains('def ') || lowerCode.contains('import os')) return 'python';
    if (lowerCode.contains('function') || lowerCode.contains('const ')) return 'javascript';
    if (lowerCode.contains('<html>')) return 'html';
    if (lowerCode.contains('select ') && lowerCode.contains('from')) return 'sql';
    return 'plaintext';
  }

  @override
  Widget? buildMessageActionTrigger(BuildContext context, WidgetRef ref, Message message) {
    final code = message.metadata?['code_snippet'] as String?;
    if (code == null) return null;
    
    final title = message.metadata?['code_title'] as String?;
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: () {
        ref.read(workbenchProvider.notifier).addTab(
          WorkbenchTab(
            id: 'code_${message.id}',
            title: title ?? 'Generated Code',
            icon: Icons.code_rounded,
            type: 'code',
            metadata: {
              'code': code,
              'language': _detectLanguage(code),
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
      child: Text(title != null ? 'View $title' : 'View Implementation'),
    );
  }

  @override
  Widget? buildWorkbenchTab(BuildContext context, WorkbenchTab tab) {
    if (tab.type != 'code') return null;
    
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
    return null;
  }
}
