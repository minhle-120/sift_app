import '../../core/models/ai_models.dart';

class DelegateToSynthesizerTool {
  static const String name = 'delegate_to_synthesizer';

  ToolDefinition get definition => ToolDefinition(
    type: 'function',
    function: FunctionDefinition(
      name: name,
      description: 'Call this when you have finished your research and want to delegate the final answer synthesis to the Chat AI model, using the most relevant knowledge chunks found.',
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
