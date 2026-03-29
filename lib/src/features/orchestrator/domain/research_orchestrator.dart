import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/tools/rag_tool.dart';
import '../../../../core/services/embedding_service.dart';
import '../../../../core/services/rerank_service.dart';
import '../../../../core/storage/sift_database.dart';
import '../../../../services/ai/i_ai_service.dart';
import '../../../../core/services/openai_service.dart';
import 'package:sift_app/src/features/chat/domain/entities/message.dart' as domain;
import '../../../../core/tools/delegate_to_synthesizer_tool.dart';
import '../../../../core/tools/no_info_found_tool.dart';
import '../../chat/presentation/controllers/settings_controller.dart';
import '../../../../core/plugins/agent_plugin.dart';
import '../../../../core/plugins/plugins_provider.dart';

final researchOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final database = AppDatabase.instance;
  final embeddingService = ref.watch(embeddingServiceProvider);
  final rerankService = ref.watch(rerankServiceProvider);
  final plugins = ref.watch(pluginsProvider);

  final ragTool = RAGTool(
    database: database,
    embeddingService: embeddingService,
    rerankService: rerankService,
    registry: ChunkRegistry(ref),
  );

  final delegateTool = DelegateToSynthesizerTool();
  final noInfoTool = NoInfoFoundTool();
  
  return ResearchOrchestrator(
    aiService: aiService,
    plugins: plugins,
    ragTool: ragTool,
    delegateTool: delegateTool,
    noInfoTool: noInfoTool,
  );
});

class ResearchOrchestrator {
  final IAiService aiService;
  final List<AgentPlugin> plugins;
  final RAGTool ragTool;
  final DelegateToSynthesizerTool delegateTool;
  final NoInfoFoundTool noInfoTool;

  ChunkRegistry get registry => ragTool.registry;

  ResearchOrchestrator({
    required this.aiService,
    required this.plugins,
    required this.ragTool,
    required this.delegateTool,
    required this.noInfoTool,
  });

  Future<ResearchResult> research({
    required int collectionId,
    required String historicalContext,
    required String userQuery,
    void Function(String status)? onStatusUpdate,
    bool Function()? isCanceled,
  }) async {
    registry.reset();
    onStatusUpdate?.call('Starting research...');

    final settings = registry.ref.read(settingsProvider);
    String systemPrompt = _buildSystemPrompt(settings);
    
    final activePlugins = plugins.where((p) => p.isEnabled(settings)).toList();

    final List<ToolDefinition> tools = [
      ragTool.definition,
      delegateTool.definition,
      noInfoTool.definition,
      ...activePlugins.map((p) => p.toolDefinition),
    ];

    String finalUserQuery = userQuery;
    for (final plugin in activePlugins) {
      if (settings.pluginModes[plugin.id] == PluginMode.on) {
        finalUserQuery = '$finalUserQuery\n\n${plugin.mandate}';
      }
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
    final Map<String, PluginResult> pluginResults = {};

    // 2. ReAct Loop
    int iterations = 0;
    const maxIterations = 5;
    bool hasQueried = false;

    while (iterations < maxIterations) {
      if (isCanceled?.call() ?? false) {
        return ResearchResult(canceled: true, steps: messages.sublist(newStepsStartIndex));
      }
      iterations++;
      
      onStatusUpdate?.call('Analyzing context (Iteration $iterations)...');
      
      final response = await aiService.chat(
        messages,
        tools: tools,
        toolChoice: 'required',
      );

      messages.add(response);

      if (response.toolCalls == null || response.toolCalls!.isEmpty) {
        return ResearchResult(
          output: response,
          steps: messages.sublist(newStepsStartIndex),
          pluginResults: pluginResults,
        );
      }

      // Handle Tool Calls
      for (final toolCall in response.toolCalls!) {
        final isQuery = toolCall.function.name == RAGTool.name;
        
        if (!hasQueried && !isQuery) {
          messages.add(ChatMessage(
            role: ChatRole.tool,
            content: 'ERROR: You must call `query_knowledge_base` first to gather information from the library before using other tools. Please call `query_knowledge_base` now.',
            toolCallId: toolCall.id,
            name: toolCall.function.name,
          ));
          continue;
        }

        if (isQuery) {
          hasQueried = true;
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
            pluginResults: pluginResults,
            steps: messages.sublist(newStepsStartIndex),
          );
        } else if (toolCall.function.name == NoInfoFoundTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          final reason = args['reason'] as String?;
          return ResearchResult(
            noInfoFound: true, 
            noInfoReason: reason,
            steps: messages.sublist(newStepsStartIndex),
            pluginResults: pluginResults,
          );
        } else {
          // Dynamic Plugin Execution
          try {
            final plugin = plugins.firstWhere((p) => p.toolName == toolCall.function.name);
            final args = _parseArgs(toolCall.function.arguments);
            
            onStatusUpdate?.call(plugin.getStatusMessage(args));
            
            String cleanContext = contextPrompt;
            for (final p in plugins) {
              cleanContext = cleanContext.replaceAll(p.mandate, '');
            }
            cleanContext = cleanContext
                .replaceAll('\n\nUser Query: ', '\n')
                .replaceAll('Current query: \n', 'Current query: ')
                .trim();

            final result = await plugin.execute(
              toolArgs: args,
              userQuery: userQuery,
              fullContext: cleanContext,
              registry: registry,
            );

            pluginResults[plugin.toolName] = result;

            messages.add(ChatMessage(
              role: ChatRole.tool,
              content: 'PLUGIN_EXECUTED: ${plugin.name} completed successfully.\n\n'
                       'Assistant Note: The plugin output has been captured and displayed to the user. '
                       'You should now call delegate_to_synthesizer to provide a textual explanation and answer any remaining parts of their query.',
              toolCallId: toolCall.id,
              name: toolCall.function.name,
            ));
          } catch (e) {
            messages.add(ChatMessage(
              role: ChatRole.tool,
              content: 'Error: Unknown tool ${toolCall.function.name} or execution failed ($e)',
              toolCallId: toolCall.id,
              name: toolCall.function.name,
            ));
          }
        }
      }
    }

    // 3. Fallback: If we hit max iterations, gather everything we found and delegate to synthesis
    final allResults = registry.getAllResults();
    if (allResults.isNotEmpty) {
      return ResearchResult(
        package: ResearchPackage(indices: allResults.map((r) => r.index).toList()),
        pluginResults: pluginResults,
        steps: messages.sublist(newStepsStartIndex),
      );
    }

    return ResearchResult(
      noInfoFound: true,
      noInfoReason: 'I have reached the maximum research depth without finding specific details in the library to answer your query.',
      steps: messages.sublist(newStepsStartIndex),
      pluginResults: pluginResults,
    );
  }

  String _buildSystemPrompt(SettingsState settings) {
    return r'''You are a Research Specialist. Your task is to locate relevant information in the database to answer user queries.
You have access to the conversation history. Use this context to resolve pronouns (e.g., "he", "they", "that project") and understand the broader goal of the user's current request.

### Core Objectives:
1. **Understand Context**: Analyze history to rephrase the query into standalone search terms if necessary.
2. **Search**: Use `query_knowledge_base` to find relevant document chunks.
3. **Reason & Refine**: After each search, analyze the chunks. If the information is incomplete, broaden your knowledge by calling `query_knowledge_base` again with different keywords. Repeat this cycle until you have a nuanced and complete understanding.
4. **No Information Found**: If you have searched multiple times and found no relevant info, call `no_info_found`. **CRITICAL**: You MUST attempt at least one search first.
5. **Specialized Delegation**: If the gathered info suits a specialized tool (e.g., graph generator, coding, flashcards), call that tool. Rely on each tool's name and description for its specific use-case.
6. **Synthesis Strategy**: Once research is complete (and any specialists called), you MUST provide a final textual overview via `finalize_research_response`.

### Rules:
- **ONLY output Tool Calls**. Do not provide any conversational text, explanations, or reasoning.
- **Cycle of Knowledge**: Do not settle for the first result. Use subsequent searches to drill down into specifics or clarify points found in earlier results.
- **Specialist Flow**: After calling any specialized tool, you MUST follow up with `finalize_research_response`.
- **Consistency**: Use the [[Chunk X]] citation format in all tool arguments if referencing specific sources.

### Flow:
1. Rephrase the query if context is complex.
2. **Knowledge Cycle**: Call `query_knowledge_base`, analyze, and repeat as needed.
3. Call a specialist tool if appropriate based on its description.
4. Call `finalize_research_response` to end the session.
''';
  }

  String buildHistory(List<domain.Message> domainMessages) {
    final StringBuffer buffer = StringBuffer();
    
    final prunedMessages = domainMessages.length > 8 
        ? domainMessages.sublist(domainMessages.length - 8) 
        : domainMessages;
    
    for (int i = 0; i < prunedMessages.length; i++) {
      final m = prunedMessages[i];
      final metadata = m.metadata;

      if (metadata != null && metadata['exclude_from_history'] == true) {
        continue;
      }

      if (m.role == domain.MessageRole.user) {
        if (buffer.isNotEmpty) buffer.write('\n\n');
        String cleanQuery = m.text;
        for (final p in plugins) {
          cleanQuery = cleanQuery.replaceAll(p.mandate, '');
        }
        cleanQuery = cleanQuery
            .replaceAll('\n\nUser Query: ', '')
            .trim();
        buffer.write('Query: $cleanQuery');
      } else if (m.role == domain.MessageRole.assistant) {
        if (m.text.trim().isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write('\n');
        final cleanAnswer = m.text.replaceAll(RegExp(r'\[\[Chunk \d+\]\]'), '');
        buffer.write('Synthesizer answer: ${cleanAnswer.trim()}');
      }
    }
    
    return buffer.toString();
  }

  Map<String, dynamic> _parseArgs(String arguments) {
    try {
      return jsonDecode(arguments);
    } catch (e) {
      return {};
    }
  }
}
