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
import '../../../../core/tools/delegate_to_coder_tool.dart';
import 'visual_orchestrator.dart';
import 'code_orchestrator.dart';
import '../../chat/presentation/controllers/settings_controller.dart';

final researchOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final visualOrchestrator = ref.watch(visualOrchestratorProvider);
  final codeOrchestrator = ref.watch(codeOrchestratorProvider);
  final database = AppDatabase.instance;
  final embeddingService = ref.watch(embeddingServiceProvider);
  final rerankService = ref.watch(rerankServiceProvider);
  
  final ragTool = RAGTool(
    database: database,
    embeddingService: embeddingService,
    rerankService: rerankService,
    registry: ChunkRegistry(ref),
  );

  final delegateTool = DelegateToSynthesizerTool();
  final noInfoTool = NoInfoFoundTool();
  final visualTool = DelegateToVisualizerTool();
  final codeTool = DelegateToCoderTool();
  
  return ResearchOrchestrator(
    aiService: aiService,
    visualOrchestrator: visualOrchestrator,
    codeOrchestrator: codeOrchestrator,
    ragTool: ragTool,
    delegateTool: delegateTool,
    noInfoTool: noInfoTool,
    visualTool: visualTool,
    codeTool: codeTool,
  );
});


class ResearchOrchestrator {
  static const String visualMandate = '**CRITICAL MANDATE**: The user has requested a visual representation. You MUST call `query_knowledge_base` first to gather data. After searching, you MUST call `delegate_to_visualizer` if you find ANY relevant data to graph, even if it is simple. Prioritize finding a visual angle for your research.';
  static const String codeMandate = '**CRITICAL MANDATE**: The user has requested to write or modify code. You MUST call `query_knowledge_base` first to gather context. After searching, you MUST call `delegate_to_coder` if the user wants code generation, script writing, or technical implementation. Do NOT write the code yourself; delegate it to the code specialist.';

  final IAiService aiService;
  final VisualOrchestrator visualOrchestrator;
  final CodeOrchestrator codeOrchestrator;
  final RAGTool ragTool;
  final DelegateToSynthesizerTool delegateTool;
  final NoInfoFoundTool noInfoTool;
  final DelegateToVisualizerTool visualTool;
  final DelegateToCoderTool codeTool;

  ChunkRegistry get registry => ragTool.registry;

  ResearchOrchestrator({
    required this.aiService,
    required this.visualOrchestrator,
    required this.codeOrchestrator,
    required this.ragTool,
    required this.delegateTool,
    required this.noInfoTool,
    required this.visualTool,
    required this.codeTool,
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
    String? currentSchema,
    void Function(String status)? onStatusUpdate,
  }) async {
    registry.reset();
    onStatusUpdate?.call('Starting research...');

    final settings = registry.ref.read(settingsProvider);

    String systemPrompt = _buildSystemPrompt();
    
    final List<ToolDefinition> tools = [
      ragTool.definition,
      delegateTool.definition,
      noInfoTool.definition,
      if (settings.visualizerMode != VisualizerMode.off) visualTool.definition,
      if (settings.coderMode != CoderMode.off) codeTool.definition,
    ];

    String finalUserQuery = userQuery;
    if (settings.visualizerMode == VisualizerMode.on) {
      finalUserQuery = '$visualMandate\n\nUser Query: $userQuery';
    }
    if (settings.coderMode == CoderMode.on) {
      finalUserQuery = '$codeMandate\n\nUser Query: $finalUserQuery';
    }

    final contextPrompt = historicalContext.isEmpty 
        ? finalUserQuery 
        : '$historicalContext\n\nCurrent query: $finalUserQuery';

    final messages = [
      ChatMessage(
        role: ChatRole.system,
        content: systemPrompt,
      ),
      ChatMessage(
        role: ChatRole.user,
        content: contextPrompt,
      ),
    ];

    final int newStepsStartIndex = messages.length;
    String? capturedVisualSchema;
    String? capturedCodeSnippet;

    // 2. ReAct Loop
    int iterations = 0;
    const maxIterations = 5;
    
    int queryRetries = 0;
    const maxQueryRetries = 3;
    bool hasQueried = false;

    while (iterations < maxIterations) {
      iterations++;
      
      onStatusUpdate?.call('Analyzing context (Iteration $iterations)...');
      
      final response = await aiService.chat(
        messages,
        tools: tools, // Use the conditionally built tools list
        toolChoice: 'required',
      );

      // --- NEW: Enforce query_knowledge_base on the first step ---
      if (!hasQueried) {
        bool calledQuery = false;
        if (response.toolCalls != null) {
          for (final toolCall in response.toolCalls!) {
            if (toolCall.function.name == RAGTool.name) {
              calledQuery = true;
              break;
            }
          }
        }
        
        if (!calledQuery) {
          queryRetries++;
          if (queryRetries >= maxQueryRetries) {
            return ResearchResult(
              noInfoFound: true,
              noInfoReason: 'Failed to search knowledge base after multiple attempts.',
              steps: messages.sublist(newStepsStartIndex),
            );
          } else {
            onStatusUpdate?.call('Enforcing knowledge search (Attempt $queryRetries)...');
            // The user requested to wipe the attempt from history and retry.
            // The model will have no idea it has ever tried this.
            continue; // Skip the rest of the loop and try again
          }
        } else {
          hasQueried = true;
        }
      }
      // -----------------------------------------------------------

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
          final result = await ragTool.execute(collectionId, args, userQuery);
          
          messages.add(ChatMessage(
            role: ChatRole.tool,
            content: result,
            toolCallId: toolCall.id,
            name: RAGTool.name,
          ));
        } else if (toolCall.function.name == DelegateToSynthesizerTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          final package = delegateTool.execute(args);
          return ResearchResult(
            package: package, 
            visualSchema: capturedVisualSchema,
            codeSnippet: capturedCodeSnippet,
            steps: messages.sublist(newStepsStartIndex),
          );
        } else if (toolCall.function.name == DelegateToVisualizerTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          onStatusUpdate?.call('Generating visualization for "${args['visualizationGoal'] ?? 'data'}..."');
          
          final package = visualTool.execute(args);
          
          // Clean the context for the visualizer (remove system mandates)
          final cleanContext = contextPrompt
              .replaceAll(visualMandate, '')
              .replaceAll('\n\nUser Query: ', '\n')
              .replaceAll('Current query: \n', 'Current query: ')
              .trim();

          final visualResult = await visualOrchestrator.visualize(
            package: package, 
            registry: registry,
            fullContext: cleanContext,
            currentSchema: currentSchema,
          );

          capturedVisualSchema = visualResult.schema;

          messages.add(ChatMessage(
            role: ChatRole.tool,
            content: 'CHART_GENERATED: ${visualResult.schema}\n\n'
                     'Assistant Note: The chart is now ready and will be displayed. '
                     'You should now call delegate_to_synthesizer to provide a textual explanation of '
                     'what the user is seeing in the chart and answer any remaining parts of their query.',
            toolCallId: toolCall.id,
            name: DelegateToVisualizerTool.name,
          ));
        } else if (toolCall.function.name == DelegateToCoderTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          onStatusUpdate?.call('Generating code for "${args['codingGoal'] ?? 'task'}..."');
          
          final package = codeTool.execute(args);
          
          final cleanContext = contextPrompt
              .replaceAll(visualMandate, '')
              .replaceAll(codeMandate, '')
              .replaceAll('\n\nUser Query: ', '\n')
              .replaceAll('Current query: \n', 'Current query: ')
              .trim();

          final codeResult = await codeOrchestrator.generateCode(
            package: package, 
            registry: registry,
            fullContext: cleanContext,
          );

          capturedCodeSnippet = codeResult.codeSnippet;

          messages.add(ChatMessage(
            role: ChatRole.tool,
            content: 'CODE_GENERATED:\n${codeResult.codeSnippet}\n\n'
                     'Assistant Note: The code has been generated and will be displayed in the workspace. '
                     'You should now call delegate_to_synthesizer to explain the implementation and '
                     'provide any additional context or instructions to the user.',
            toolCallId: toolCall.id,
            name: DelegateToCoderTool.name,
          ));
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
    return r'''You are a Research Specialist. Your task is to locate relevant information in the database to answer user queries.
You have access to the conversation history. Use this context to resolve pronouns (e.g., "he", "they", "that project") and understand the broader goal of the user's current request.

### Core Objectives:
1. **Understand Context**: Analyze the provided conversation history to rephrase the user's latest query into standalone search terms if necessary.
2. **Search**: Use `query_knowledge_base` to find relevant document chunks.
3. **Evaluate**: Review the returned chunks. If more information is needed, search again with different keywords or queries.
4. **No Information Found**: If you have searched and found no relevant information to answer the user query accurately, call `no_info_found`. **CRITICAL**: You MUST attempt at least one `query_knowledge_base` call before concluding that no information exists.
5. **Synthesis**: If you have enough info to answer as text, call `finalize_research_response`. **CRITICAL**: Do NOT use this tool if the user's request involves showing, writing, or modifying code.
6. **Visualization**: If the data is inherently visual (comparisons, trends, hierarchies, complex relationships), call `delegate_to_visualizer` with the relevant chunks. After calling this, you will receive confirmation and the generated JSON schema. You MUST then use that context to provide a final textual response via `finalize_research_response`.
7. **Code Generation**: If the user asks to show, write, generate, or modify code, you MUST call `delegate_to_coder` with the relevant chunks. This is the ONLY tool for handling code. After calling this, you will receive confirmation and the generated code. You MUST then use that context to provide a final textual response via `finalize_research_response` to explain the results.
 
 ### Rules:
 - **ONLY output Tool Calls**. Do not provide any conversational text, explanations, or reasoning.
 - **No Code in Final Response**: `finalize_research_response` is for textual summaries and analysis only. NEVER use it to output code blocks, scripts, or implementation details; use `delegate_to_coder` for that.
 - Use the conversation history to ensure your searches are targeted and context-aware.
 - **Search First**: Do NOT call `no_info_found` unless you have already received search results that were irrelevant or insufficient.
 - If you call `no_info_found`, the research session will terminate immediately.
 - **Visual/Code-Text Synergy**: When you call `delegate_to_visualizer` or `delegate_to_coder`, the system prepares the result in the workspace. You MUST follow up by calling `finalize_research_response` so the user gets both the interactive result and your textual explanation.
 - Do not take shortcuts or skip any of the user's request.
 - Your mission is complete when you have delegated the work via `finalize_research_response` or called `no_info_found`.

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
        // Strip mandates from historical user queries to keep context clean
        final cleanQuery = m.text
            .replaceAll(visualMandate, '')
            .replaceAll(codeMandate, '')
            .replaceAll('\n\nUser Query: ', '')
            .trim();
        buffer.write('Query: $cleanQuery');
      } else if (m.role == domain.MessageRole.assistant) {
        if (buffer.isNotEmpty) buffer.write('\n');
        // Strip Citations: Remove [[Chunk X]] markers to keep history clean for the researcher
        final cleanAnswer = m.text.replaceAll(RegExp(r'\[\[Chunk \d+\]\]'), '');
        buffer.write('Synthesizer answer: ${cleanAnswer.trim()}');
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
