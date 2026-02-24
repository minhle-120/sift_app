import '../models/ai_models.dart';

class DelegateToCoderTool {
  static const String name = 'delegate_to_coder';

  ToolDefinition get definition => ToolDefinition(
        function: FunctionDefinition(
          name: name,
          description: 'Delegate to a specialist coder when the user asks to write, generate, or modify code. Only call this after you have gathered sufficient evidence chunks or context.',
          parameters: {
            'type': 'object',
            'properties': {
              'indices': {
                'type': 'array',
                'items': {'type': 'integer'},
                'description': 'The indices of the chunks [[Chunk X]] providing necessary context, documentation, or examples for the code.',
              },
              'codingGoal': {
                'type': 'string',
                'description': 'Describe exactly what code should be written (e.g., "Write a Python script to parse this JSON", "Implement a sorting algorithm").',
              },
            },
            'required': ['indices', 'codingGoal'],
          },
        ),
      );

  CodePackage execute(Map<String, dynamic> args) {
    final indices = List<int>.from(args['indices'] ?? []);
    final goal = args['codingGoal'] as String? ?? 'Write code';
    return CodePackage(indices: indices, codingGoal: goal);
  }
}
