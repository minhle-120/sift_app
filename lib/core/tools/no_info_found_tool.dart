import '../../core/models/ai_models.dart';

class NoInfoFoundTool {
  static const String name = 'no_info_found';

  ToolDefinition get definition => ToolDefinition(
        type: 'function',
        function: FunctionDefinition(
          name: name,
          description: 'Call this when you have searched the knowledge base and found NO relevant information to answer the user query. This stops the research process and informs the user.',
          parameters: {
            'type': 'object',
            'properties': {
              'reason': {
                'type': 'string',
                'description': 'A brief explanation of what was searched and why no info was found.',
              }
            },
            'required': ['reason'],
          },
        ),
      );

  void execute(Map<String, dynamic> args) {
    // No-op for execution, we just need the trigger in the orchestrator
  }
}
