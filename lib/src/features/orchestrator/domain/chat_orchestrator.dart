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
    String? codeSnippet,
    String? flashcardTitle,
    int? flashcardCount,
  }) async {
    // 1. Resolve and Sort Chunks
    final List<String> resolvedChunks = _resolveSortedChunks(package, registry);

    // 2. Build Message List
    final combinedUserMessage = buildCombinedMessage(
      resolvedChunks,
      originalQuery,
      visualSchema: visualSchema,
      codeSnippet: codeSnippet,
      flashcardTitle: flashcardTitle,
      flashcardCount: flashcardCount,
    );

    final messages = [
      ChatMessage(role: ChatRole.system, content: buildSystemPrompt()),
      ...conversation,
      ChatMessage(role: ChatRole.user, content: combinedUserMessage),
    ];

    // 3. Generate Final Response
    return await aiService.chat(messages);
  }

  Stream<ChatStreamChunk> streamSynthesize({
    required String originalQuery,
    required List<ChatMessage> conversation,
    required ResearchPackage package,
    required ChunkRegistry registry,
    String? visualSchema,
    String? codeSnippet,
    String? flashcardTitle,
    int? flashcardCount,
  }) async* {
    // 1. Resolve and Sort Chunks
    final List<String> resolvedChunks = _resolveSortedChunks(package, registry);

    // 2. Build Message List
    final combinedUserMessage = buildCombinedMessage(
      resolvedChunks,
      originalQuery,
      visualSchema: visualSchema,
      codeSnippet: codeSnippet,
      flashcardTitle: flashcardTitle,
      flashcardCount: flashcardCount,
    );

    final messages = [
      ChatMessage(role: ChatRole.system, content: buildSystemPrompt()),
      ...conversation,
      ChatMessage(role: ChatRole.user, content: combinedUserMessage),
    ];

    // 3. Yield chunks from the stream
    yield* aiService.streamChat(messages);
  }

  /// Builds a clean user-visible history from domain messages.
  /// This excludes internal tool calls and internal research steps.
  /// Limits history to the last 4 turns (8 messages).
  List<ChatMessage> buildHistory(List<domain.Message> domainMessages, {int? limit = 8}) {
    final List<ChatMessage> history = [];

    // History Pruning: only prune if limit is provided
    final prunedMessages = (limit != null && domainMessages.length > limit)
        ? domainMessages.sublist(domainMessages.length - limit)
        : domainMessages;

    for (final m in prunedMessages) {
      if (m.metadata != null && m.metadata!['exclude_from_history'] == true) {
        continue;
      }

      String content = m.text;
      if (m.role == domain.MessageRole.assistant) {
        if (content.trim().isEmpty) continue; // Skip empty assistant messages (placeholders)
        // Strip historical citations to avoid confusing the LLM with old chunk references
        content = content.replaceAll(RegExp(r'\[\[Chunk \d+\]\]'), '').trim();
      }

      history.add(ChatMessage(
        role: m.role == domain.MessageRole.user ? ChatRole.user : ChatRole.assistant,
        content: content,
        reasoning: m.reasoning,
      ));
    }
    return history;
  }

  String buildSystemPrompt() {
    return r'''You are Sift, a helpful AI assistant. Your goal is to answer the user's question accurately using the provided background knowledge chunks.

### Citation Rules:
1. **Strict Format**: EVERY piece of information from the background context MUST be cited using exactly this format: [[Chunk X]] where X is the chunk number.
2. **Immediate Placement**: Place citations immediately after the sentence or claim they support, not just at the end of a paragraph.
3. **No Alternatives**: NEVER use formats like "(Chunk 1)", "Source 1", or "according to xyz". ONLY use the [[Chunk X]] tag.
4. **Multiple Sources**: If multiple chunks support a claim, list them all: [[Chunk 1]][[Chunk 2]].

### Math Formatting:
- **ALWAYS use LaTeX** for any mathematical expressions, formulas or equations (note: do not apply LaTeX for simple measurements like 1m, 1kg, etc.).
- **Inline Math**: Use single dollar signs: $ E=mc^2 $.
- **Block Math**: Use double dollar signs for complex or standalone equations: $$ P(A|B) = \frac{P(A \cap B)}{P(B)} $$.
- **Consistency**: Do not mix LaTeX with plain text symbols (like using * instead of \times).

### Instructions:
- Answer the user's latest query accurately using the provided context.
- **Explain Visuals & Code**: 
  - If a RENDERED_CHART is provided, provide a textual explanation of the chart.
  - If a WRITTEN_CODE is provided, provide a textual explanation of the code.
- **NO Redundancy**: Do NOT attempt to redraw the chart or rewrite the entire code block in your response. Focus on synthesis and explanation.
- **Study Support**: 
  - If a FLASHCARD_DECK is mentioned in the message, acknowledge its creation (e.g., "I've created a study deck with X cards in the Memory tab").
  - Encourage the user to use the cards for reinforcement.
- Be honest: If the context doesn't contain the answer, state that "The provided documents do not contain information about [topic]."
- Maintain a professional, objective, and helpful tone.
''';
  }

  String buildLiteSystemPrompt() {
    return r'''You are Sift, a helpful AI assistant. Your goal is to answer the user's question accurately using the provided background knowledge chunks.

### Instructions:
1. **Cite Sources**: Whenever you use information from a background chunk, you MUST cite it at the end of the sentence as [[Chunk X]] where X is the number (e.g., "The sky is blue [[Chunk 1]].").
2. **Math**: Use LaTeX for all math: $E=mc^2$ for inline, and $$...$$ for blocks.
3. **Stick to Context**: Only answer based on the provided chunks. If the answer isn't there, say you don't know.
4. **Tone**: Be concise, professional, and helpful.
''';
  }

  String buildCombinedMessage(
    List<String> chunks, 
    String query, {
    String? visualSchema, 
    String? codeSnippet,
    String? flashcardTitle,
    int? flashcardCount,
    List<ChatMessage>? history,
  }) {
    final historySection = (history != null && history.isNotEmpty)
        ? '### Background History (Last Turn):\n${history.map((m) => '${m.role == ChatRole.user ? 'User' : 'Assistant'}: ${m.content}').join('\n')}\n\n'
        : '';

    return '''$historySection### Knowledge Chunks:
${chunks.join('\n\n')}

${visualSchema != null ? '### RENDERED_CHART\n$visualSchema\n(Note: This chart has already been displayed to the user in a separate tab. Do NOT redraw it.)\n\n' : ''}${codeSnippet != null ? '### WRITTEN_CODE\n$codeSnippet\n(Note: This code has already been displayed to the user. USE THIS CODE TO ANSWER THE QUERY. Start answer with "Here is the explanation of the code...")\n\n' : ''}${flashcardTitle != null ? '### FLASHCARD_DECK\nTitle: $flashcardTitle\nCount: $flashcardCount\n(Note: This study deck has been generated. Acknowledge this in your response.)\n\n' : ''}### User Query:
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
