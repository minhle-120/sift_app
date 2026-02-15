import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/services/openai_service.dart';
import '../../../../services/ai/i_ai_service.dart';

final chatOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return ChatOrchestrator(aiService: aiService);
});

class ChatOrchestrator {
  final IAiService aiService;

  ChatOrchestrator({required this.aiService});

  Future<ChatMessage> synthesize({
    required String originalQuery,
    required List<ChatMessage> conversation,
    required ResearchPackage package,
    required ChunkRegistry registry,
  }) async {
    // 1. Resolve Chunks
    final List<String> resolvedChunks = [];
    for (final index in package.indices) {
      final res = registry.getResult(index);
      if (res != null) {
        resolvedChunks.add('[[Chunk $index]]\n${res.content}');
      }
    }

    // 2. Build Message List
    final combinedUserMessage = _buildCombinedMessage(resolvedChunks, originalQuery);
    
    final messages = [
      ChatMessage(role: ChatRole.system, content: _buildSystemPrompt()),
      ...conversation,
      ChatMessage(role: ChatRole.user, content: combinedUserMessage),
    ];

    // 3. Generate Final Response
    return await aiService.chat(messages);
  }

  String _buildSystemPrompt() {
    return '''You are Sift, a helpful AI assistant. Your goal is to answer the user's question accurately using the provided background knowledge chunks.
You have access to the full conversation history. Use it to maintain context, resolve references, and ensure your response flows naturally from previous interactions.

### Citation Rules:
1. **Strict Format**: EVERY piece of information from the background context MUST be cited using exactly this format: `[[Chunk X]]` where X is the chunk number.
2. **Immediate Placement**: Place citations immediately after the sentence or claim they support, not just at the end of a paragraph.
3. **No Alternatives**: NEVER use formats like "(Chunk 1)", "Source 1", or "according to Bender et al.". ONLY use the `[[Chunk X]]` tag.
4. **Multiple Sources**: If multiple chunks support a claim, list them all: `[[Chunk 1]][[Chunk 2]]`.

### Instructions:
- Answer the user's latest query accurately using the provided context.
- Be honest: If the context doesn't contain the answer, state that "The provided documents do not contain information about [topic]."
- Maintain a professional, objective, and helpful tone.
''';
  }

  String _buildCombinedMessage(List<String> chunks, String query) {
    return '''### Knowledge Chunks:
${chunks.join('\n\n')}

### User Query:
$query
''';
  }
}
