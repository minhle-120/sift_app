import '../models/ai_models.dart';

class DelegateToGraphGeneratorTool {
  static const String name = 'delegate_to_graph_generator';

  ToolDefinition get definition => ToolDefinition(
        function: FunctionDefinition(
          name: name,
          description: 'Delegate to a graph drawer when you find complex relationships, hierarchies, or comparative data that should be visualized as an interactive graph.',
          parameters: {
            'type': 'object',
            'properties': {
              'graphGoal': {
                'type': 'string',
                'description': 'Describe exactly what should be graphed (e.g., "Compare water usage between Google and Microsoft", "Show the hierarchy of LLM infrastructure").',
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

  GraphPackage execute(Map<String, dynamic> args) {
    final indices = List<int>.from(args['indices'] ?? []);
    final goal = args['graphGoal'] as String? ?? 'Generate graph';
    return GraphPackage(indices: indices, graphGoal: goal);
  }
}
