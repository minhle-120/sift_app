import '../../core/models/ai_models.dart';

class DelegateToFlashcardsTool {
  static const String name = 'delegate_to_flashcards';

  ToolDefinition get definition => ToolDefinition(
        function: FunctionDefinition(
          name: name,
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

  FlashcardPackage execute(Map<String, dynamic> args) {
    final List<dynamic> indicesRaw = args['indices'] ?? [];
    final List<int> indices = indicesRaw.map((e) => e as int).toList();
    final String studyGoal = args['studyGoal'] ?? 'General study';

    return FlashcardPackage(
      indices: indices,
      studyGoal: studyGoal,
    );
  }
}
