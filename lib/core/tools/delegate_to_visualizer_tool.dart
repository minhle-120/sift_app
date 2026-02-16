import '../models/ai_models.dart';

class DelegateToVisualizerTool {
  static const String name = 'delegate_to_visualizer';

  ToolDefinition get definition => ToolDefinition(
        function: FunctionDefinition(
          name: name,
          description: 'Delegate to a visualization specialist when you find complex relationships, hierarchies, or comparative data that should be graphed. Only call this after you have gathered sufficient evidence chunks.',
          parameters: {
            'type': 'object',
            'properties': {
              'indices': {
                'type': 'array',
                'items': {'type': 'integer'},
                'description': 'The indices of the chunks [[Chunk X]] containing the data to visualize.',
              },
              'visualizationGoal': {
                'type': 'string',
                'description': 'Describe exactly what should be visualized (e.g., "Compare water usage between Google and Microsoft", "Show the hierarchy of LLM infrastructure").',
              },
            },
            'required': ['indices', 'visualizationGoal'],
          },
        ),
      );

  VisualPackage execute(Map<String, dynamic> args) {
    final indices = List<int>.from(args['indices'] ?? []);
    final goal = args['visualizationGoal'] as String? ?? 'Visualize findings';
    return VisualPackage(indices: indices, visualizationGoal: goal);
  }
}
