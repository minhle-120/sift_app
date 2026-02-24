import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/services/openai_service.dart';
import '../../../../services/ai/i_ai_service.dart';

final codeOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return CodeOrchestrator(aiService: aiService);
});

class CodeOrchestrator {
  final IAiService aiService;

  CodeOrchestrator({required this.aiService});

  Future<CodeResult> generateCode({
    required CodePackage package,
    required ChunkRegistry registry,
    String? fullContext,
  }) async {
    // 1. Resolve Chunks
    final List<String> resolvedChunks = [];
    for (final index in package.indices) {
      final res = registry.getResult(index);
      if (res != null) {
        resolvedChunks.add('[[Chunk $index]]\n${res.content}');
      }
    }

    // 2. Build Bundled Message
    final StringBuffer contentBuffer = StringBuffer();

    if (fullContext != null) {
      contentBuffer.writeln('### CONVERSATION HISTORY');
      contentBuffer.writeln(fullContext);
      contentBuffer.writeln();
    }

    contentBuffer.writeln('### CODING GOAL');
    contentBuffer.writeln('Goal: ${package.codingGoal}');
    contentBuffer.writeln();
    contentBuffer.writeln('### CONTEXT CHUNKS');
    contentBuffer.writeln(resolvedChunks.join('\n\n'));

    final messages = [
      ChatMessage(role: ChatRole.system, content: _buildSystemPrompt()),
      ChatMessage(
        role: ChatRole.user,
        content: contentBuffer.toString().trim(),
      ),
    ];

    // 3. Generate Code
    final response = await aiService.chat(messages);
    final (cleanCode, lang) = _extractCodeAndLanguage(response.content);

    // 4. Return result
    return CodeResult(
      package: package,
      codeSnippet: cleanCode,
      language: lang,
      steps: [
        ChatMessage(
          role: response.role,
          content: cleanCode,
          toolCalls: response.toolCalls,
        )
      ],
    );
  }

  (String, String) _extractCodeAndLanguage(String text) {
    if (text.contains('```')) {
      final lines = text.split('\n');
      final startIndex = lines.indexWhere((l) => l.startsWith('```'));
      final endIndex = lines.lastIndexWhere((l) => l.startsWith('```'));
      
      if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
        final startLine = lines[startIndex];
        // Extract language from ```lang (e.g. ```python extra_info -> python)
        final langPart = startLine.replaceFirst('```', '').trim();
        final language = langPart.split(RegExp(r'\s+')).first;
        
        final code = lines.sublist(startIndex + 1, endIndex).join('\n').trim();
        return (code, language.isEmpty ? 'plaintext' : language);
      }
    }
    return (text.trim(), 'plaintext');
  }

  String _buildSystemPrompt() {
    return '''You are an expert Software Engineer. Your task is to generate high-quality, functional, and clean code based on the provided research context and goal.

### GUIDELINES:
1. **Focus**: Only output the code itself. 
2. **Explanations**: Do NOT provide explanations, apologies, or conversational text. Your output will be processed by another AI that will handle the explanation.
3. **Completeness**: Ensure the code is complete and follows best practices for the target language.
4. **Markdown**: Use markdown code blocks to wrap your code, e.g. ```python ... ```.

### OUTPUT:
Generate only the requested code block.
''';
  }
}
