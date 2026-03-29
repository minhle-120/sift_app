import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agent_plugin.dart';
import '../models/ai_models.dart';
import '../../src/features/chat/domain/entities/message.dart';
import '../../src/features/chat/presentation/controllers/settings_controller.dart';
import '../../src/features/chat/presentation/controllers/workbench_controller.dart';
import '../../src/features/orchestrator/domain/flashcard_orchestrator.dart';
import '../../src/features/chat/presentation/widgets/flashcard_viewer.dart';

class FlashcardPlugin extends AgentPlugin {
  final FlashcardOrchestrator _orchestrator;

  FlashcardPlugin(this._orchestrator);

  @override
  String get id => 'flashcard';

  @override
  String get name => 'Flashcards';
  
  @override
  IconData get icon => Icons.school_outlined;

  @override
  String get toolName => 'delegate_to_flashcards';

  @override
  ToolDefinition get toolDefinition => ToolDefinition(
    function: FunctionDefinition(
      name: toolName,
      description: 'Delegates to the Flashcard Specialist to transform research chunks into study materials. Use this when the user wants to memorize, learn, or study the gathered information. You MUST call query_knowledge_base first.',
      parameters: {
        'type': 'object',
        'properties': {
          'studyGoal': {
            'type': 'string',
            'description': 'What specifically the user wants to learn or the exam they are preparing for.',
          },
          'indices': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'The indices of the chunks to use for flashcard generation (e.g. [1, 3, 5])',
          },
        },
        'required': ['studyGoal', 'indices'],
      },
    ),
  );

  @override
  String get mandate => '**CRITICAL MANDATE**: The user has requested flashcards or study materials. You MUST call `query_knowledge_base` first to gather factual context. After searching, you MUST call `delegate_to_flashcards` to transform that data into a high-quality study deck.';

  @override
  String getStatusMessage(Map<String, dynamic> toolArgs) {
    final goal = toolArgs['studyGoal'] as String? ?? 'General study';
    return 'Designing study deck for "$goal"...';
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
    final String studyGoal = toolArgs['studyGoal'] ?? 'General study';
    final package = FlashcardPackage(indices: indices, studyGoal: studyGoal);

    final result = await _orchestrator.generateFlashcards(
      package: package,
      registry: registry,
      fullContext: fullContext,
    );

    return PluginResult(
      metadataToPersist: {
        'cards': result.cards.map((e) => e.toJson()).toList(),
        'flashcard_title': result.title,
      },
      resultData: result,
    );
  }
  @override
  ArtifactContent getArtifactContent(PluginResult result) {
    final data = result.resultData as FlashcardResult?;
    if (data == null || data.cards.isEmpty) {
      return ArtifactContent(type: 'FLASHCARD_DECK', body: 'No flashcards generated.');
    }

    final buffer = StringBuffer();
    buffer.writeln('Topic: ${data.title}');
    for (int i = 0; i < data.cards.length; i++) {
      final card = data.cards[i];
      buffer.writeln('${i + 1}. Question: ${card.question}');
      buffer.writeln('   Answer: ${card.answer}');
    }

    return ArtifactContent(
      type: 'FLASHCARD_DECK',
      body: buffer.toString().trim(),
    );
  }

  @override
  void onResult(PluginResult result, String messageId, Ref ref) {
    final data = result.resultData as FlashcardResult?;
    if (data == null) return;

    List<dynamic> finalCards = data.cards.map((c) => c.toJson()).toList();
    String targetId = 'cards_$messageId';

    ref.read(workbenchProvider.notifier).addTab(
      WorkbenchTab(
        id: targetId,
        title: data.title,
        icon: Icons.sports_esports_outlined,
        type: 'flashcards',
        metadata: {
          'cards': finalCards,
          'flashcard_title': data.title,
        },
      ),
    );
  }

  @override
  Widget? buildMessageActionTrigger(BuildContext context, WidgetRef ref, Message message) {
    final cards = message.metadata?['cards'];
    if (cards == null) return null;

    final title = message.metadata?['flashcard_title'] as String? ?? 'Study Deck';
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: () {
        ref.read(workbenchProvider.notifier).addTab(
          WorkbenchTab(
            id: 'cards_${message.id}',
            title: title,
            icon: Icons.sports_esports_outlined,
            type: 'flashcards',
            metadata: {
              'cards': cards,
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
      child: Text('View $title'),
    );
  }

  @override
  Widget? buildWorkbenchTab(BuildContext context, WorkbenchTab tab) {
    if (tab.type != 'flashcards') return null;
    
    final meta = tab.metadata as Map<String, dynamic>?;
    final cardsRaw = meta?['cards'] as List<dynamic>?;
    
    if (cardsRaw != null) {
      // Decode inside the view builder
      final List<Flashcard> parsed = [];
      for (final c in cardsRaw) {
        if (c is Map<String, dynamic>) {
           parsed.add(Flashcard.fromJson(c));
        } else if (c is Flashcard) {
           parsed.add(c);
        }
      }
      return FlashcardViewer(
        key: ValueKey(tab.id),
        cards: parsed,
      );
    }
    return null;
  }
}
