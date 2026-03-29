import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/services/openai_service.dart';
import '../../../../services/ai/i_ai_service.dart';
import '../../../../core/services/document_processor.dart';
import '../../../../src/features/chat/domain/entities/message.dart' as domain;
import '../../chat/presentation/controllers/settings_controller.dart';
import '../../../../core/plugins/agent_plugin.dart';
import '../../../../core/plugins/plugins_provider.dart';
import 'dart:io';
import 'dart:convert';

final chatOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final processor = ref.watch(documentProcessorProvider);
  final plugins = ref.watch(pluginsProvider);
  return ChatOrchestrator(aiService: aiService, processor: processor, plugins: plugins);
});

class ChatOrchestrator {
  final IAiService aiService;
  final DocumentProcessor processor;
  final List<AgentPlugin> plugins;

  ChatOrchestrator({required this.aiService, required this.processor, required this.plugins});

  Future<ChatMessage> synthesize({
    required String originalQuery,
    required List<ChatMessage> conversation,
    required ResearchPackage package,
    required ChunkRegistry registry,
    Map<String, PluginResult>? pluginResults,
  }) async {
    // 1. Resolve and Sort Chunks
    final List<String> resolvedChunks = _resolveSortedChunks(package, registry);

    // 2. Build Message List
    final combinedUserMessage = buildCombinedMessage(
      resolvedChunks,
      originalQuery,
      pluginResults: pluginResults,
    );

    final settings = registry.ref.read(settingsProvider);
    final messages = [
      ChatMessage(role: ChatRole.system, content: buildSystemPrompt(settings)),
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
    Map<String, PluginResult>? pluginResults,
  }) async* {
    // 1. Resolve and Sort Chunks
    final List<String> resolvedChunks = _resolveSortedChunks(package, registry);

    // 2. Build Message List
    final combinedUserMessage = buildCombinedMessage(
      resolvedChunks,
      originalQuery,
      pluginResults: pluginResults,
    );

    final settings = registry.ref.read(settingsProvider);
    final messages = [
      ChatMessage(role: ChatRole.system, content: buildSystemPrompt(settings)),
      ...conversation,
      ChatMessage(role: ChatRole.user, content: combinedUserMessage),
    ];

    // 3. Yield chunks from the stream
    yield* aiService.streamChat(messages);
  }

  Future<List<ChatMessage>> buildHistory(List<domain.Message> domainMessages, {int? limit = 8}) async {
    final List<ChatMessage> history = [];

    final prunedMessages = (limit != null && domainMessages.length > limit)
        ? domainMessages.sublist(domainMessages.length - limit)
        : domainMessages;

    for (final m in prunedMessages) {
      if (m.metadata != null && m.metadata!['exclude_from_history'] == true) {
        continue;
      }

      String text = m.text;
      if (m.role == domain.MessageRole.assistant) {
        if (text.trim().isEmpty) continue;
        text = text.replaceAll(RegExp(r'\[\[Chunk \d+\]\]'), '').trim();
      }

      if (m.role == domain.MessageRole.user && m.metadata != null && m.metadata!['attachments'] != null) {
        final List<dynamic> attachmentData = m.metadata!['attachments'];
        final parts = <ContentPart>[];
        
        for (final item in attachmentData) {
          final path = item['path'] as String?;
          if (path == null) continue;
          
          final file = File(path);
          if (!await file.exists()) continue;

          final name = item['name'] ?? 'file';
          final extension = (item['extension'] as String? ?? '').toLowerCase();
          final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);

          if (isImage) {
            final bytes = await file.readAsBytes();
            parts.add(ImagePart(base64Encode(bytes), mimeType: 'image/${extension == 'jpg' ? 'jpeg' : extension}'));
          } else {
            final extracted = await processor.extractText(file, extension: extension);
            if (extracted.isNotEmpty) {
              parts.add(TextPart('--- Previous File: $name ---\n$extracted\n---\n\n'));
            }
          }
        }

        if (text.isNotEmpty) {
          parts.add(TextPart(text));
        }

        history.add(ChatMessage(
          role: ChatRole.user,
          content: parts.isNotEmpty ? parts : text,
          reasoning: m.reasoning,
        ));
      } else {
        history.add(ChatMessage(
          role: m.role == domain.MessageRole.user ? ChatRole.user : ChatRole.assistant,
          content: text,
          reasoning: m.reasoning,
        ));
      }
    }
    return history;
  }

  String buildSystemPrompt(SettingsState settings) {
    return '''You are Sift, a helpful AI assistant. Your goal is to answer the user's question accurately using the provided background knowledge chunks.

### Citation Rules:
1. **Strict Format**: EVERY piece of information from the background context MUST be cited using exactly this format: [[Chunk X]] where X is the chunk number.
2. **Immediate Placement**: Place citations immediately after the sentence or claim they support, not just at the end of a paragraph.
3. **No Alternatives**: NEVER use formats like "(Chunk 1)", "Source 1", or "according to xyz". ONLY use the [[Chunk X]] tag.
4. **Multiple Sources**: If multiple chunks support a claim, list them all: [[Chunk 1]][[Chunk 2]].

### Math Formatting:
- **Use LaTeX** for any mathematical expressions, formulas or equations (note: do not apply LaTeX for simple measurements like 1m, 1kg, etc.. Just write them as they are).
- **Inline Math**: Use single dollar signs: \$ E=mc^2 \$.
- **Block Math**: Use double dollar signs for complex or standalone equations: \$\$ P(A|B) = \\frac{P(A \\cap B)}{P(B)} \$\$.
- **Consistency**: Do not mix LaTeX with plain text symbols (like using * instead of \\times).

### Instructions:
- Answer the user's latest query accurately using the provided context.
- **Synthesize Specialists**: If the input context contains artifacts like WRITTEN_CODE, RENDERED_GRAPH, INTERACTIVE_CANVAS, or FLASHCARD_DECK, provide a textual explanation and acknowledge their creation. Do NOT redraw or rewrite them.
- Be honest: If the context doesn't contain the answer, state that "The provided documents do not contain information about [topic]."
- Maintain a professional, objective, and helpful tone.
''';
  }

  String buildLiteSystemPrompt() {
    return r'''You are Sift, a helpful AI assistant. Your goal is to answer the user's question accurately using the provided background knowledge chunks.

### Instructions:
1. **Cite Sources**: Whenever you use information from a background chunk, you MUST cite it at the end of the sentence as [[Chunk X]] where X is the number (e.g., "The sky is blue [[Chunk 5]].").
2. **Use LaTeX** for any mathematical expressions, formulas or equations (note: do not apply LaTeX for simple measurements like 1m, 1kg, etc.. Just write them as they are).
3. **Stick to Context**: Only answer based on the provided chunks. If the answer isn't there, say you don't know.
4. **Tone**: Be concise, professional, and helpful.
''';
  }

  String buildCombinedMessage(
    List<String> chunks, 
    String query, {
    Map<String, PluginResult>? pluginResults,
    List<ChatMessage>? history,
  }) {
    final historySection = (history != null && history.isNotEmpty)
        ? '### Background History (Last Turn):\n${history.map((m) => '${m.role == ChatRole.user ? 'User' : 'Assistant'}: ${m.content}').join('\n')}\n\n'
        : '';

    final pluginInjections = StringBuffer();
    if (pluginResults != null) {
      for (final entry in pluginResults.entries) {
        try {
          final plugin = plugins.firstWhere((p) => p.toolName == entry.key);
          final artifact = plugin.getArtifactContent(entry.value);
          
          pluginInjections.writeln('### ARTIFACT_CONTENT: ${artifact.type}');
          pluginInjections.writeln(artifact.body);
          pluginInjections.writeln('(Note: This artifact has been rendered and displayed to the user. Acknowledge its creation and synthesize the content above into your explanation. Do NOT reproduce the source data directly unless asked.)');
          pluginInjections.writeln();
        } catch (_) {}
      }
    }

    return '''$historySection### Knowledge Chunks:
${chunks.join('\n\n')}

$pluginInjections### User Query:
$query
''';
  }

  List<String> _resolveSortedChunks(ResearchPackage package, ChunkRegistry registry) {
    final List<RAGResult> results = [];
    for (final index in package.indices) {
      final res = registry.getResult(index);
      if (res != null) results.add(res);
    }

    results.sort((a, b) {
      final docCompare = a.documentId.compareTo(b.documentId);
      if (docCompare != 0) return docCompare;
      return a.chunkIndex.compareTo(b.chunkIndex);
    });

    return results.map((res) => '[[Chunk ${res.index}]]\n${res.content}').toList();
  }
}
