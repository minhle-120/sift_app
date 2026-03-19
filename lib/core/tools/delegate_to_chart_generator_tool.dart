import '../models/ai_models.dart';

class DelegateToChartGeneratorTool {
  static const String name = 'delegate_to_chart_generator';

  ToolDefinition get definition => ToolDefinition(
        function: FunctionDefinition(
          name: name,
          description: 'Delegate to a chart drawer when you find complex relationships, hierarchies, or comparative data that should be graphed or generated as an interactive chart.',
          parameters: {
            'type': 'object',
            'properties': {
              'chartGoal': {
                'type': 'string',
                'description': 'Describe exactly what should be charted (e.g., "Compare water usage between Google and Microsoft", "Show the hierarchy of LLM infrastructure").',
              },
              'indices': {
                'type': 'array',
                'items': {'type': 'integer'},
                'description': 'The indices of the chunks [[Chunk X]] containing the data to visualize.',
              },
            },
            'required': ['chartGoal', 'indices'],
          },
        ),
      );

  ChartPackage execute(Map<String, dynamic> args) {
    final indices = List<int>.from(args['indices'] ?? []);
    final goal = args['chartGoal'] as String? ?? 'Generate chart';
    return ChartPackage(indices: indices, chartGoal: goal);
  }
}
