import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/tools/rag_tool.dart';
import '../../../../core/services/openai_service.dart';
import '../../../../core/services/embedding_service.dart';
import '../../../../core/services/rerank_service.dart';
import '../../../../core/storage/sift_database.dart';
import '../../../../services/ai/i_ai_service.dart';
import '../../../../core/tools/finalize_research_tool.dart';

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

  final finalizeTool = FinalizeResearchTool();
  
  return ResearchOrchestrator(
    aiService: aiService,
    ragTool: ragTool,
    finalizeTool: finalizeTool,
  );
});

class ResearchResult {
  final ChatMessage? output;
  final ResearchPackage? package;

  ResearchResult({this.output, this.package});
}

class ResearchOrchestrator {
  final IAiService aiService;
  final RAGTool ragTool;
  final FinalizeResearchTool finalizeTool;

  ChunkRegistry get registry => ragTool.registry;

  ResearchOrchestrator({
    required this.aiService,
    required this.ragTool,
    required this.finalizeTool,
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
        content: 'Original Request: $userQuery',
      ),
    ];

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
          finalizeTool.definition,
        ],
      );

      messages.add(response);

      if (response.toolCalls == null || response.toolCalls!.isEmpty) {
        // AI returned a final message (or choice to not use tools)
        return ResearchResult(output: response);
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
        } else if (toolCall.function.name == FinalizeResearchTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          final package = finalizeTool.execute(args);
          return ResearchResult(package: package);
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
      output: ChatMessage(
        role: ChatRole.assistant,
        content: 'I have reached the maximum research depth. Here is what I found:\n\n'
                 '${messages.lastWhere((m) => m.role == ChatRole.tool, orElse: () => ChatMessage(role: ChatRole.assistant, content: 'No results found.')).content}',
      ),
    );
  }

  String _buildSystemPrompt() {
    return '''You are a Research Specialist. Your task is to locate relevant information in the database to answer user queries.

### Core Objectives:
1. **Search**: Use `query_knowledge_base` to find relevant document chunks.
2. **Evaluate**: Review the returned chunks. If more information is needed, search again with different keywords or queries.
3. **Submit**: Once you have found enough relevant information, call `finalize_research` with the indices of the most relevant chunks.

### Rules:
- **ONLY output Tool Calls**. Do not provide any conversational text, explanations, or reasoning.
- Use stable indices (e.g., [[Chunk 1]]) provided in the search results.
- Your mission is complete when you have submitted the indices via `finalize_research`.

### Example:
User: "What are the latest revenue forecasts for Project X?"
Tool Call: query_knowledge_base(keywords="Project X revenue", query="What are the revenue forecasts for Project X?")
Observation: [[Chunk 1]] ...
Tool Call: finalize_research(indices=[1])
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
