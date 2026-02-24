import '../../core/models/ai_models.dart';

class DelegateToSynthesizerTool {
  static const String name = 'finalize_research_response';

  ToolDefinition get definition => ToolDefinition(
    type: 'function',
    function: FunctionDefinition(
      name: name,
      description: 'Call this when you have finished your research and want to provide the final textual answer. Use this ONLY for summaries and analysis. NEVER use this for code generation; use delegate_to_coder for implementations.',
      parameters: {
        'type': 'object',
        'properties': {
          'indices': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'The indices of the chunks (e.g. [[Chunk 1]]) that are most relevant to the user query.',
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
