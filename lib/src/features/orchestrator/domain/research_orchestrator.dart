import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/tools/rag_tool.dart';
import '../../../../core/services/openai_service.dart';
import '../../../../core/services/embedding_service.dart';
import '../../../../core/services/rerank_service.dart';
import '../../../../core/storage/sift_database.dart';
import '../../../../services/ai/i_ai_service.dart';
import 'package:sift_app/src/features/chat/domain/entities/message.dart' as domain;
import '../../../../core/tools/delegate_to_synthesizer_tool.dart';
import '../../../../core/tools/no_info_found_tool.dart';
import '../../../../core/tools/delegate_to_visualizer_tool.dart';

final researchOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final database = AppDatabase.instance;
  final embeddingService = ref.watch(embeddingServiceProvider);
  final rerankService = ref.watch(rerankServiceProvider);
  
  final ragTool = RAGTool(
    database: database,
    embeddingService: embeddingService,
    rerankService: rerankService,
    registry: ChunkRegistry(),
  );

  final delegateTool = DelegateToSynthesizerTool();
  final noInfoTool = NoInfoFoundTool();
  final visualTool = DelegateToVisualizerTool();
  
  return ResearchOrchestrator(
    aiService: aiService,
    ragTool: ragTool,
    delegateTool: delegateTool,
    noInfoTool: noInfoTool,
    visualTool: visualTool,
  );
});


class ResearchOrchestrator {
  final IAiService aiService;
  final RAGTool ragTool;
  final DelegateToSynthesizerTool delegateTool;
  final NoInfoFoundTool noInfoTool;
  final DelegateToVisualizerTool visualTool;

  ChunkRegistry get registry => ragTool.registry;

  ResearchOrchestrator({
    required this.aiService,
    required this.ragTool,
    required this.delegateTool,
    required this.noInfoTool,
    required this.visualTool,
  });

  /// Starts a research session for a given query and context.
  /// [collectionId] is the local library to search.
  /// [historicalContext] is the formatted string of previous turns.
  /// [userQuery] is the specific question to answer.
  /// [onStatusUpdate] is called as the AI moves through the research steps.
  Future<ResearchResult> research({
    required int collectionId,
    required String historicalContext,
    required String userQuery,
    void Function(String status)? onStatusUpdate,
  }) async {
    registry.reset();
    onStatusUpdate?.call('Starting research...');

    // 1. Prepare Unified Context Message
    // This bundles all previous turns and the current query into one user message.
    final contextPrompt = historicalContext.isEmpty 
        ? userQuery 
        : '$historicalContext\n\nCurrent query: $userQuery';

    final messages = [
      ChatMessage(
        role: ChatRole.system,
        content: _buildSystemPrompt(),
      ),
      ChatMessage(
        role: ChatRole.user,
        content: contextPrompt,
      ),
    ];

    final int newStepsStartIndex = messages.length; // Start capturing steps AFTER the context message

    // 2. ReAct Loop
    int iterations = 0;
    const maxIterations = 5;

    while (iterations < maxIterations) {
      iterations++;
      
      onStatusUpdate?.call('Analyzing context (Iteration $iterations)...');
      
      final response = await aiService.chat(
        messages,
        tools: [
          ragTool.definition,
          delegateTool.definition,
          visualTool.definition,
          noInfoTool.definition,
        ],
        toolChoice: 'required',
      );

      messages.add(response);

      if (response.toolCalls == null || response.toolCalls!.isEmpty) {
        // AI returned a final message (or choice to not use tools)
        return ResearchResult(
          output: response,
          steps: messages.sublist(newStepsStartIndex),
        );
      }

      // Handle Tool Calls
      for (final toolCall in response.toolCalls!) {
        if (toolCall.function.name == RAGTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          onStatusUpdate?.call('Searching library for "${args['keywords'] ?? 'relevant info'}"...');
          final result = await ragTool.execute(collectionId, args);
          
          messages.add(ChatMessage(
            role: ChatRole.tool,
            content: result,
            toolCallId: toolCall.id,
            name: RAGTool.name,
          ));
        } else if (toolCall.function.name == DelegateToSynthesizerTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          final package = delegateTool.execute(args);
          return ResearchResult(package: package, steps: messages.sublist(newStepsStartIndex));
        } else if (toolCall.function.name == DelegateToVisualizerTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          final package = visualTool.execute(args);
          return ResearchResult(
            visualPackage: package,
            steps: messages.sublist(newStepsStartIndex),
          );
        } else if (toolCall.function.name == NoInfoFoundTool.name) {
          // AI specifically said no info found
          final args = _parseArgs(toolCall.function.arguments);
          final reason = args['reason'] as String?;
          return ResearchResult(
            noInfoFound: true, 
            noInfoReason: reason,
            steps: messages.sublist(newStepsStartIndex),
          );
        } else {
          // Handle other tools or error
          messages.add(ChatMessage(
            role: ChatRole.tool,
            content: 'Error: Unknown tool ${toolCall.function.name}',
            toolCallId: toolCall.id,
            name: toolCall.function.name,
          ));
        }
      }
    }

    return ResearchResult(
      steps: messages.sublist(newStepsStartIndex),
      output: ChatMessage(
        role: ChatRole.assistant,
        content: 'I have reached the maximum research depth. Here is what I found:\n\n'
                 '${messages.lastWhere((m) => m.role == ChatRole.tool, orElse: () => ChatMessage(role: ChatRole.assistant, content: 'No results found.')).content}',
      ),
    );
  }

  String _buildSystemPrompt() {
    return '''You are a Research Specialist. Your task is to locate relevant information in the database to answer user queries.
You have access to the conversation history. Use this context to resolve pronouns (e.g., "he", "they", "that project") and understand the broader goal of the user's current request.

### Core Objectives:
1. **Understand Context**: Analyze the provided conversation history to rephrase the user's latest query into standalone search terms if necessary.
2. **Search**: Use `query_knowledge_base` to find relevant document chunks.
3. **Evaluate**: Review the returned chunks. If more information is needed, search again with different keywords or queries.
4. **No Information Found**: If you have searched and found no relevant information to answer the user query accurately, call `no_info_found`. **CRITICAL**: You MUST attempt at least one `query_knowledge_base` call before concluding that no information exists.
5. **Synthesis**: If you have enough info to answer as text, call `delegate_to_synthesizer`.
6. **Visualization**: If the data is inherently visual (comparisons, trends, hierarchies, complex relationships), call `delegate_to_visualizer` with the relevant chunks.

### Rules:
- **ONLY output Tool Calls**. Do not provide any conversational text, explanations, or reasoning.
- Use the conversation history to ensure your searches are targeted and context-aware.
- **Search First**: Do NOT call `no_info_found` unless you have already received search results that were irrelevant or insufficient.
- If you call `no_info_found`, the research session will terminate immediately.
- Your mission is complete when you have delegated the work via `delegate_to_synthesizer` or called `no_info_found`.
''';
  }

  /// Builds a clean user-assistant chat history string from domain messages.
  /// This excludes all internal research steps and tool traces.
  /// Limits history to the last 4 turns (8 messages).
  String buildHistory(List<domain.Message> domainMessages) {
    final StringBuffer buffer = StringBuffer();
    
    // History Pruning: Only keep the last 4 turns (8 messages)
    final prunedMessages = domainMessages.length > 8 
        ? domainMessages.sublist(domainMessages.length - 8) 
        : domainMessages;
    
    for (int i = 0; i < prunedMessages.length; i++) {
      final m = prunedMessages[i];
      final metadata = m.metadata;

      // Skip messages that are explicitly marked for exclusion (e.g., pruned 'no info' turns)
      if (metadata != null && metadata['exclude_from_history'] == true) {
        continue;
      }

      if (m.role == domain.MessageRole.user) {
        if (buffer.isNotEmpty) buffer.write('\n\n');
        buffer.write('Query: ${m.text}');
      } else if (m.role == domain.MessageRole.assistant) {
        if (buffer.isNotEmpty) buffer.write('\n');
        // Strip Citations: Remove [[Chunk X]] markers to keep history clean for the researcher
        final cleanText = m.text.replaceAll(RegExp(r'\[\[Chunk \d+\]\]'), '');
        buffer.write('Synthesizer answer: ${cleanText.trim()}');
      }
    }
    
    return buffer.toString();
  }

  Map<String, dynamic> _parseArgs(String arguments) {
    try {
      // Basic JSON parsing
      return jsonDecode(arguments);
    } catch (e) {
      return {};
    }
  }
}
