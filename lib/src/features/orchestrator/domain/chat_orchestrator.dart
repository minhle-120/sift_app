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
      final content = registry.getContent(index);
      if (content != null) {
        resolvedChunks.add('[[Chunk $index]]\n$content');
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

### Instructions:
- Answer the user's query located at the end of the message.
- Use the provided context to answer questions.
- Cite your sources using the chunk tags (e.g., [[Chunk 1]]) when referencing specific information.
- If the context doesn't contain the answer, be honest and explain what's missing.
- Keep your tone professional, helpful, and concise.
- Output ONLY the final answer. No internal reasoning or meta-talk.
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
