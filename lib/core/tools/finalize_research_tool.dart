import '../../core/models/ai_models.dart';

class FinalizeResearchTool {
  static const String name = 'finalize_research';

  ToolDefinition get definition => ToolDefinition(
    type: 'function',
    function: FunctionDefinition(
      name: name,
      description: 'Call this when you have finished your research and want to submit your findings to the Chat AI for the final answer.',
      parameters: {
        'type': 'object',
        'properties': {
          'indices': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'The indices of the chunks (e.g. [[Chunk 1]]) that are most relevant to the final answer.',
          },
        },
        'required': ['indices'],
      },
    ),
  );

  ResearchPackage execute(Map<String, dynamic> args) {
    final List<dynamic> rawIndices = args['indices'] ?? [];
    final List<int> indices = rawIndices.map((e) => e as int).toList();
    return ResearchPackage(indices: indices);
  }
}
