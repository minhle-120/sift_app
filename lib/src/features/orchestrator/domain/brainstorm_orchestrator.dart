import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../services/ai/i_ai_service.dart';
import '../../../../core/services/openai_service.dart';

final brainstormOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return BrainstormOrchestrator(aiService: aiService);
});

class BrainstormOrchestrator {
  final IAiService aiService;

  BrainstormOrchestrator({required this.aiService});

  Stream<ChatStreamChunk> streamBrainstorm({
    required List<ChatMessage> history,
    required String query,
  }) async* {
    final messages = [
      ChatMessage(role: ChatRole.system, content: _buildBrainstormSystemPrompt()),
      ...history,
      ChatMessage(role: ChatRole.user, content: query),
    ];

    yield* aiService.streamChat(messages);
  }

  String _buildBrainstormSystemPrompt() {
    return r'''You are Sift's Brainstorming Assistant. You are currently in Brainstorm Mode, which means you are chatting directly with the user without access to their document library.

### Your Mission:
- Help the user brainstorm ideas, solve problems, or explore topics using your broad internal knowledge.
- Be creative, analytical, and highly helpful.
- If the user asks about specific documents they uploaded, remind them that you are in Brainstorm Mode and they should switch back to Research Mode if they want you to consult their library.
- Use context from the previous conversation to maintain continuity.

### Formatting:
- **Markdown**: Use Markdown for clear structure (headers, bullet points, bold text).
- **Math**: ALWAYS use LaTeX for any mathematical expressions.
  - Inline Math: $ E=mc^2 $
  - Block Math: $$ P(A|B) = \frac{P(A \cap B)}{P(B)} $$
- Maintain a professional yet collaborative and high-energy tone.
''';
  }
}
