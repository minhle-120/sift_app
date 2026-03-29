import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agent_plugin.dart';
import '../models/ai_models.dart';
import '../../src/features/chat/domain/entities/message.dart';
import '../../src/features/chat/presentation/controllers/settings_controller.dart';
import '../../src/features/chat/presentation/controllers/workbench_controller.dart';
import '../../src/features/orchestrator/domain/quiz_orchestrator.dart';
import '../../src/features/chat/presentation/widgets/quiz_viewer.dart';

class QuizPlugin extends AgentPlugin {
  final QuizOrchestrator _orchestrator;

  QuizPlugin(this._orchestrator);

  @override
  String get id => 'quiz';

  @override
  String get name => 'Quiz';
  
  @override
  IconData get icon => Icons.quiz_rounded;

  @override
  String get toolName => 'delegate_to_quiz_generator';

  @override
  ToolDefinition get toolDefinition => ToolDefinition(
    function: FunctionDefinition(
      name: toolName,
      description: 'Delegate to the Quiz Master to generate a 4-question multiple-choice quiz based on gathered research. Use this when the user wants to test their knowledge or explicitly asks for a quiz.',
      parameters: {
        'type': 'object',
        'properties': {
          'topicGoal': {
            'type': 'string',
            'description': 'What specifically the user wants to be quizzed on.',
          },
          'indices': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'The indices of the chunks to use for generating the quiz (e.g. [1, 3, 5])',
          },
        },
        'required': ['topicGoal', 'indices'],
      },
    ),
  );

  @override
  String get mandate => '**CRITICAL MANDATE**: The user has requested a quiz. You MUST call `query_knowledge_base` first to gather factual context. After searching, you MUST call `delegate_to_quiz_generator` to generate a 4-question multiple-choice quiz testing the user on that material.';

  @override
  String getStatusMessage(Map<String, dynamic> toolArgs) {
    final goal = toolArgs['topicGoal'] as String? ?? 'General Knowledge';
    return 'Drafting quiz on "$goal"...';
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
    final List<dynamic> indicesRaw = toolArgs['indices'] ?? [];
    final List<int> indices = indicesRaw.map((e) => e as int).toList();
    final String topicGoal = toolArgs['topicGoal'] ?? 'General topic';
    final package = QuizPackage(indices: indices, topicGoal: topicGoal);

    final result = await _orchestrator.generateQuiz(
      package: package,
      registry: registry,
      fullContext: fullContext,
    );

    return PluginResult(
      metadataToPersist: {
        'quiz_title': result.title,
        'quiz_questions': result.questions.map((e) => e.toJson()).toList(),
      },
      resultData: result,
    );
  }

  @override
  ArtifactContent getArtifactContent(PluginResult result) {
    final data = result.resultData as QuizResult?;
    if (data == null || data.questions.isEmpty) {
      return ArtifactContent(type: 'QUIZ', body: 'No questions generated.');
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Title: ${data.title}');
    for (int i = 0; i < data.questions.length; i++) {
      final q = data.questions[i];
      buffer.writeln('${i + 1}. Question: ${q.question}');
      buffer.writeln('   Options: ${q.options.join(', ')}');
      buffer.writeln('   Explanation: ${q.explanation}');
    }

    return ArtifactContent(
      type: 'QUIZ',
      body: buffer.toString().trim(),
    );
  }

  @override
  void onResult(PluginResult result, String messageId, Ref ref) {
    final data = result.resultData as QuizResult?;
    if (data == null || data.questions.isEmpty) return;

    ref.read(workbenchProvider.notifier).addTab(
      WorkbenchTab(
        id: 'quiz_$messageId',
        title: data.title,
        icon: Icons.quiz_outlined,
        type: 'quiz',
        metadata: {
          'quiz_questions': data.questions.map((q) => q.toJson()).toList(),
          'quiz_title': data.title,
        },
      ),
    );
  }

  @override
  Widget? buildMessageActionTrigger(BuildContext context, WidgetRef ref, Message message) {
    final questions = message.metadata?['quiz_questions'];
    if (questions == null) return null;

    final title = message.metadata?['quiz_title'] as String? ?? 'Quiz';
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: () {
        ref.read(workbenchProvider.notifier).addTab(
          WorkbenchTab(
            id: 'quiz_${message.id}',
            title: title,
            icon: Icons.quiz_outlined,
            type: 'quiz',
            metadata: {
              'quiz_questions': questions,
              'quiz_title': title,
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
      child: Text(title),
    );
  }

  @override
  Widget? buildWorkbenchTab(BuildContext context, WorkbenchTab tab) {
    if (tab.type != 'quiz') return null;
    
    final meta = tab.metadata as Map<String, dynamic>?;
    final questionsRaw = meta?['quiz_questions'] as List<dynamic>?;
    
    if (questionsRaw != null) {
      final questions = questionsRaw.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>)).toList();
      return QuizViewer(
        key: ValueKey(tab.id),
        questions: questions,
      );
    }
    return null;
  }
}
