import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/services/openai_service.dart';
import '../../../../services/ai/i_ai_service.dart';
import 'package:sift_app/src/features/chat/domain/entities/message.dart' as domain;

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
    String? visualSchema,
  }) async {
    // 1. Resolve and Sort Chunks
    final List<String> resolvedChunks = _resolveSortedChunks(package, registry);

    // 2. Build Message List
    final combinedUserMessage = _buildCombinedMessage(
      resolvedChunks,
      originalQuery,
      visualSchema: visualSchema,
    );

    final messages = [
      ChatMessage(role: ChatRole.system, content: _buildSystemPrompt()),
      ...conversation,
      ChatMessage(role: ChatRole.user, content: combinedUserMessage),
    ];

    // 3. Generate Final Response
    return await aiService.chat(messages);
  }

  Stream<String> streamSynthesize({
    required String originalQuery,
    required List<ChatMessage> conversation,
    required ResearchPackage package,
    required ChunkRegistry registry,
    String? visualSchema,
  }) async* {
    // 1. Resolve and Sort Chunks
    final List<String> resolvedChunks = _resolveSortedChunks(package, registry);

    // 2. Build Message List
    final combinedUserMessage = _buildCombinedMessage(
      resolvedChunks,
      originalQuery,
      visualSchema: visualSchema,
    );

    final messages = [
      ChatMessage(role: ChatRole.system, content: _buildSystemPrompt()),
      ...conversation,
      ChatMessage(role: ChatRole.user, content: combinedUserMessage),
    ];

    // 3. Yield chunks from the stream
    yield* aiService.streamChat(messages);
  }

  /// Builds a clean user-visible history from domain messages.
  /// This excludes internal tool calls and internal research steps.
  /// Limits history to the last 4 turns (8 messages).
  List<ChatMessage> buildHistory(List<domain.Message> domainMessages) {
    final List<ChatMessage> history = [];

    // History Pruning: Only keep the last 4 turns (8 messages)
    final prunedMessages = domainMessages.length > 8
        ? domainMessages.sublist(domainMessages.length - 8)
        : domainMessages;

    for (final m in prunedMessages) {
      if (m.metadata != null && m.metadata!['exclude_from_history'] == true) {
        continue;
      }

      history.add(ChatMessage(
        role: m.role == domain.MessageRole.user ? ChatRole.user : ChatRole.assistant,
        content: m.text,
      ));
    }
    return history;
  }

  String _buildSystemPrompt() {
    return '''You are Sift, a helpful AI assistant. Your goal is to answer the user's question accurately using the provided background knowledge chunks.

### Citation Rules:
1. **Strict Format**: EVERY piece of information from the background context MUST be cited using exactly this format: `[[Chunk X]]` where X is the chunk number.
2. **Immediate Placement**: Place citations immediately after the sentence or claim they support, not just at the end of a paragraph.
3. **No Alternatives**: NEVER use formats like "(Chunk 1)", "Source 1", or "according to xyz". ONLY use the `[[Chunk X]]` tag.
4. **Multiple Sources**: If multiple chunks support a claim, list them all: `[[Chunk 1]][[Chunk 2]]`.

### Instructions:
- Answer the user's latest query accurately using the provided context.
- **Explain Visuals**: If a [VISUAL_CHART_CONTEXT] is provided, it means a interactive chart has ALREADY been rendered in the UI workbench. You MUST provide a textual explanation of what is shown in that chart and how it relates to the research findings. 
- **NO Redundancy**: Do NOT attempt to redraw the chart as ASCII, markdown lists, or tables if they would just repeat the visual chart. Focus on providing high-level synthesis and answering questions.
- Be honest: If the context doesn't contain the answer, state that "The provided documents do not contain information about [topic]."
- Maintain a professional, objective, and helpful tone.
''';
  }

  String _buildCombinedMessage(List<String> chunks, String query, {String? visualSchema}) {
    return '''${visualSchema != null ? '[RENDERED_VISUAL_CHART_CONTEXT]\n$visualSchema\n(Note: The chart above has already been displayed to the user in a separate tab. Do NOT redraw it.)\n\n' : ''}### Knowledge Chunks:
${chunks.join('\n\n')}

### User Query:
$query
''';
  }

  List<String> _resolveSortedChunks(ResearchPackage package, ChunkRegistry registry) {
    final List<RAGResult> results = [];
    for (final index in package.indices) {
      final res = registry.getResult(index);
      if (res != null) results.add(res);
    }

    // Sort chronologically (by document and then by position in document)
    results.sort((a, b) {
      final docCompare = a.documentId.compareTo(b.documentId);
      if (docCompare != 0) return docCompare;
      return a.chunkIndex.compareTo(b.chunkIndex);
    });

    return results.map((res) => '[[Chunk ${res.index}]]\n${res.content}').toList();
  }
}
