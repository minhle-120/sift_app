import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/tools/rag_tool.dart';
import '../../../../core/services/openai_service.dart';
import '../../../../core/services/embedding_service.dart';
import '../../../../core/services/rerank_service.dart';
import '../../../../core/storage/sift_database.dart';
import '../../../../services/ai/i_ai_service.dart';
import '../../../../core/tools/delegate_to_synthesizer_tool.dart';
import '../../../../core/tools/no_info_found_tool.dart';

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
  
  return ResearchOrchestrator(
    aiService: aiService,
    ragTool: ragTool,
    delegateTool: delegateTool,
    noInfoTool: noInfoTool,
  );
});


class ResearchOrchestrator {
  final IAiService aiService;
  final RAGTool ragTool;
  final DelegateToSynthesizerTool delegateTool;
  final NoInfoFoundTool noInfoTool;

  ChunkRegistry get registry => ragTool.registry;

  ResearchOrchestrator({
    required this.aiService,
    required this.ragTool,
    required this.delegateTool,
    required this.noInfoTool,
  });

  /// Starts a research session for a given query and context.
  /// [collectionId] is the local library to search.
  /// [conversation] is the list of visible messages.
  /// [userQuery] is the specific question to answer.
  /// [onStatusUpdate] is called as the AI moves through the research steps.
  Future<ResearchResult> research({
    required int collectionId,
    required List<ChatMessage> conversation,
    required String userQuery,
    void Function(String status)? onStatusUpdate,
  }) async {
    registry.reset();
    onStatusUpdate?.call('Starting research...');

    // 1. Prepare Initial Messages
    final messages = [
      ChatMessage(
        role: ChatRole.system,
        content: _buildSystemPrompt(),
      ),
      ...conversation,
      ChatMessage(
        role: ChatRole.user,
        content: userQuery,
      ),
    ];

    final int newStepsStartIndex = messages.length; // Start capturing steps AFTER the user query

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
5. **Delegate**: Once you have found enough relevant information, call `delegate_to_synthesizer` with the indices of the most relevant chunks. This hands off the final answer generation to a specialized Chat model.

### Rules:
- **ONLY output Tool Calls**. Do not provide any conversational text, explanations, or reasoning.
- Use the conversation history to ensure your searches are targeted and context-aware.
- **Search First**: Do NOT call `no_info_found` unless you have already received search results that were irrelevant or insufficient.
- If you call `no_info_found`, the research session will terminate immediately.
- Your mission is complete when you have delegated the work via `delegate_to_synthesizer` or called `no_info_found`.
''';
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
