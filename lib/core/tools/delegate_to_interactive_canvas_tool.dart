import '../models/ai_models.dart';

class DelegateToInteractiveCanvasTool {
  static const String name = 'delegate_to_interactive_canvas';

  ToolDefinition get definition => ToolDefinition(
        function: FunctionDefinition(
          name: name,
          description: 'Useful for generating highly custom static visual representations of research data using HTML/CSS/SVG. Use this when a standard chart is not enough and you want to create a rich, structured visual display (e.g., custom timelines, multi-column reports, SVG infographics).',
          parameters: {
            'type': 'object',
            'properties': {
              'canvasGoal': {
                'type': 'string',
                'description': 'Describe exactly what should be rendered in the canvas (e.g., "A visual SVG of the solar system", "A formatted HTML medical report with custom styling").',
              },
              'indices': {
                'type': 'array',
                'items': {'type': 'integer'},
                'description': 'The indices of the chunks [[Chunk X]] containing the data to visualize.',
              },
            },
            'required': ['canvasGoal', 'indices'],
          },
        ),
      );

  InteractiveCanvasPackage execute(Map<String, dynamic> args) {
    final indices = List<int>.from(args['indices'] ?? []);
    final goal = args['canvasGoal'] as String? ?? 'Generate interactive canvas';
    return InteractiveCanvasPackage(indices: indices, canvasGoal: goal);
  }
}
