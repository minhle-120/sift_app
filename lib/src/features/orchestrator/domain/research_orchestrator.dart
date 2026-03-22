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
import '../../../../core/tools/delegate_to_chart_generator_tool.dart';
import '../../../../core/tools/delegate_to_coder_tool.dart';
import 'chart_generator_orchestrator.dart';
import 'code_orchestrator.dart';
import 'flashcard_orchestrator.dart';
import '../../chat/presentation/controllers/settings_controller.dart';
import '../../../../core/tools/delegate_to_flashcards_tool.dart';
import '../../../../core/tools/delegate_to_interactive_canvas_tool.dart';
import 'interactive_canvas_orchestrator.dart';

final researchOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final chartGeneratorOrchestrator = ref.watch(chartGeneratorOrchestratorProvider);
  final codeOrchestrator = ref.watch(codeOrchestratorProvider);
  final flashcardOrchestrator = ref.watch(flashcardOrchestratorProvider);
  final interactiveCanvasOrchestrator = ref.watch(interactiveCanvasOrchestratorProvider);
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
  final chartTool = DelegateToChartGeneratorTool();
  final codeTool = DelegateToCoderTool();
  final flashcardTool = DelegateToFlashcardsTool();
  final canvasTool = DelegateToInteractiveCanvasTool();
  
  return ResearchOrchestrator(
    aiService: aiService,
    chartGeneratorOrchestrator: chartGeneratorOrchestrator,
    codeOrchestrator: codeOrchestrator,
    flashcardOrchestrator: flashcardOrchestrator,
    ragTool: ragTool,
    delegateTool: delegateTool,
    noInfoTool: noInfoTool,
    chartTool: chartTool,
    codeTool: codeTool,
    flashcardTool: flashcardTool,
    canvasTool: canvasTool,
    interactiveCanvasOrchestrator: interactiveCanvasOrchestrator,
  );
});


class ResearchOrchestrator {
  static const String chartMandate = '**CRITICAL MANDATE**: The user has requested a visual representation. You MUST call `query_knowledge_base` first to gather data. After searching, you MUST call `delegate_to_chart_generator` if you find ANY relevant data to graph, even if it is simple. Prioritize finding a visual angle for your research.';
  static const String codeMandate = '**CRITICAL MANDATE**: The user has requested to write or modify code. You MUST call `query_knowledge_base` first to gather context. After searching, you MUST call `delegate_to_coder` if the user wants code generation, script writing, or technical implementation. Do NOT write the code yourself; delegate it to the code specialist.';
  static const String flashcardMandate = '**CRITICAL MANDATE**: The user has requested flashcards or study materials. You MUST call `query_knowledge_base` first to gather factual context. After searching, you MUST call `delegate_to_flashcards` to transform that data into a high-quality study deck.';
  static const String canvasMandate = '**CRITICAL MANDATE**: The user has requested a custom visual display component. You MUST call `query_knowledge_base` first. After searching, you MUST call `delegate_to_interactive_canvas` to build the static visual component using HTML/SVG.';

  final IAiService aiService;
  final ChartGeneratorOrchestrator chartGeneratorOrchestrator;
  final CodeOrchestrator codeOrchestrator;
  final FlashcardOrchestrator flashcardOrchestrator;
  final RAGTool ragTool;
  final DelegateToSynthesizerTool delegateTool;
  final NoInfoFoundTool noInfoTool;
  final DelegateToChartGeneratorTool chartTool;
  final DelegateToCoderTool codeTool;
  final DelegateToFlashcardsTool flashcardTool;
  final DelegateToInteractiveCanvasTool canvasTool;
  final InteractiveCanvasOrchestrator interactiveCanvasOrchestrator;

  ChunkRegistry get registry => ragTool.registry;

  ResearchOrchestrator({
    required this.aiService,
    required this.chartGeneratorOrchestrator,
    required this.codeOrchestrator,
    required this.flashcardOrchestrator,
    required this.ragTool,
    required this.delegateTool,
    required this.noInfoTool,
    required this.chartTool,
    required this.codeTool,
    required this.flashcardTool,
    required this.canvasTool,
    required this.interactiveCanvasOrchestrator,
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
    String? currentChartSchema,
    String? currentCode,
    String? currentCodeTitle,
    List<Flashcard>? currentFlashcards,
    String? currentCanvasHtml,
    void Function(String status)? onStatusUpdate,
    bool Function()? isCanceled,
  }) async {
    registry.reset();
    onStatusUpdate?.call('Starting research...');

    final settings = registry.ref.read(settingsProvider);

    String systemPrompt = _buildSystemPrompt(settings);
    
    final List<ToolDefinition> tools = [
      ragTool.definition,
      delegateTool.definition,
      noInfoTool.definition,
      if (settings.chartGeneratorMode != ChartGeneratorMode.off) chartTool.definition,
      if (settings.coderMode != CoderMode.off) codeTool.definition,
      if (settings.flashcardMode != FlashcardMode.off) flashcardTool.definition,
      if (settings.interactiveCanvasMode != InteractiveCanvasMode.off) canvasTool.definition,
    ];

    String finalUserQuery = userQuery;
    if (settings.chartGeneratorMode == ChartGeneratorMode.on) {
      finalUserQuery = '$finalUserQuery\n\n$chartMandate';
    }
    if (settings.coderMode == CoderMode.on) {
      finalUserQuery = '$finalUserQuery\n\n$codeMandate';
    }
    if (settings.flashcardMode == FlashcardMode.on) {
      finalUserQuery = '$finalUserQuery\n\n$flashcardMandate';
    }
    if (settings.interactiveCanvasMode == InteractiveCanvasMode.on) {
      finalUserQuery = '$finalUserQuery\n\n$canvasMandate';
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
    String? capturedChartSchema;
    String? capturedCodeSnippet;
    String? capturedCodeLanguage;
    String? capturedCodeTitle;
    List<Flashcard>? capturedFlashcards;
    String? capturedFlashcardTitle;
    String? capturedCanvasHtml;

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
        tools: tools, // Use the conditionally built tools list
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
        final isQuery = toolCall.function.name == RAGTool.name;
        
        if (!hasQueried && !isQuery) {
          // Enforcement error
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
            chartSchema: capturedChartSchema,
            codeSnippet: capturedCodeSnippet,
            codeLanguage: capturedCodeLanguage,
            codeTitle: capturedCodeTitle,
            flashcardResult: capturedFlashcards,
            flashcardTitle: capturedFlashcardTitle,
            canvasHtml: capturedCanvasHtml,
            steps: messages.sublist(newStepsStartIndex),
          );
        } else if (toolCall.function.name == DelegateToChartGeneratorTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          onStatusUpdate?.call('Generating chart for "${args['chartGoal'] ?? 'data'}..."');
          
          final package = chartTool.execute(args);
          
          // Clean the context for the generator (remove system mandates)
          final cleanContext = contextPrompt
              .replaceAll(chartMandate, '')
              .replaceAll('\n\nUser Query: ', '\n')
              .replaceAll('Current query: \n', 'Current query: ')
              .trim();

          final chartResult = await chartGeneratorOrchestrator.generateChart(
            package: package, 
            registry: registry,
            fullContext: cleanContext,
            currentChartSchema: currentChartSchema,
          );

          capturedChartSchema = chartResult.schema;

          messages.add(ChatMessage(
            role: ChatRole.tool,
            content: 'CHART_GENERATED: ${chartResult.schema}\n\n'
                     'Assistant Note: The chart is now ready and will be displayed. '
                     'You should now call delegate_to_synthesizer to provide a textual explanation of '
                     'what the user is seeing in the chart and answer any remaining parts of their query.',
            toolCallId: toolCall.id,
            name: DelegateToChartGeneratorTool.name,
          ));
        } else if (toolCall.function.name == DelegateToCoderTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          onStatusUpdate?.call('Generating code for "${args['codingGoal'] ?? 'task'}..."');
          
          final package = codeTool.execute(args);
          
          final cleanContext = contextPrompt
              .replaceAll(chartMandate, '')
              .replaceAll(codeMandate, '')
              .replaceAll('\n\nUser Query: ', '\n')
              .replaceAll('Current query: \n', 'Current query: ')
              .trim();

          final codeResult = await codeOrchestrator.generateCode(
            package: package, 
            registry: registry,
            fullContext: cleanContext,
            currentCode: currentCode,
            currentCodeTitle: currentCodeTitle,
          );

          capturedCodeSnippet = codeResult.codeSnippet;
          capturedCodeLanguage = codeResult.language;
          capturedCodeTitle = codeResult.title;

          messages.add(ChatMessage(
            role: ChatRole.tool,
            content: 'CODE_GENERATED:\n${codeResult.codeSnippet}\n\n'
                     'Assistant Note: The code has been generated and will be displayed in the workspace. '
                     'You should now call delegate_to_synthesizer to explain the implementation and '
                     'provide any additional context or instructions to the user.',
            toolCallId: toolCall.id,
            name: DelegateToCoderTool.name,
          ));
        } else if (toolCall.function.name == DelegateToFlashcardsTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          onStatusUpdate?.call('Designing study deck for "${args['studyGoal'] ?? 'topic'}..."');
          
          final package = flashcardTool.execute(args);
          
          final cleanContext = contextPrompt
              .replaceAll(chartMandate, '')
              .replaceAll(codeMandate, '')
              .replaceAll(flashcardMandate, '')
              .replaceAll('\n\nUser Query: ', '\n')
              .replaceAll('Current query: \n', 'Current query: ')
              .trim();

          final flashcardResult = await flashcardOrchestrator.generateFlashcards(
            package: package, 
            registry: registry,
            fullContext: cleanContext,
            currentCards: currentFlashcards,
          );

          capturedFlashcards = flashcardResult.cards;
          capturedFlashcardTitle = flashcardResult.title;

          messages.add(ChatMessage(
            role: ChatRole.tool,
            content: 'FLASHCARDS_GENERATED: ${flashcardResult.cards.length} cards in deck "${flashcardResult.title}"\n\n'
                     'Assistant Note: The study deck has been generated and added to the workspace. '
                     'You should now call delegate_to_synthesizer to explain the key concepts covered in the flashcards '
                     'and encourage the user to test their knowledge.',
            toolCallId: toolCall.id,
            name: DelegateToFlashcardsTool.name,
          ));
        } else if (toolCall.function.name == DelegateToInteractiveCanvasTool.name) {
          final args = _parseArgs(toolCall.function.arguments);
          onStatusUpdate?.call('Designing visual layout for "${args['canvasGoal'] ?? 'component'}..."');
          
          final package = canvasTool.execute(args);
          
          final cleanContext = contextPrompt
              .replaceAll(chartMandate, '')
              .replaceAll(codeMandate, '')
              .replaceAll(flashcardMandate, '')
              .replaceAll(canvasMandate, '')
              .replaceAll('\n\nUser Query: ', '\n')
              .replaceAll('Current query: \n', 'Current query: ')
              .trim();

          final canvasResult = await interactiveCanvasOrchestrator.generateCanvas(
            package: package, 
            registry: registry,
            fullContext: cleanContext,
          );

          capturedCanvasHtml = canvasResult.htmlContent;

          messages.add(ChatMessage(
            role: ChatRole.tool,
            content: 'CANVAS_GENERATED:\n${canvasResult.htmlContent.substring(0, canvasResult.htmlContent.length > 200 ? 200 : canvasResult.htmlContent.length)}...\n\n'
                     'Assistant Note: The interactive canvas has been generated and will be displayed in the workspace. '
                     'You should now call delegate_to_synthesizer to explain how the user can interact with this component '
                     'and summarize its key takeaways.',
            toolCallId: toolCall.id,
            name: DelegateToInteractiveCanvasTool.name,
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

    // 3. Fallback: If we hit max iterations, gather everything we found and delegate to synthesis
    final allResults = registry.getAllResults();
    if (allResults.isNotEmpty) {
      return ResearchResult(
        package: ResearchPackage(indices: allResults.map((r) => r.index).toList()),
        chartSchema: capturedChartSchema,
        codeSnippet: capturedCodeSnippet,
        codeLanguage: capturedCodeLanguage,
        codeTitle: capturedCodeTitle,
        flashcardResult: capturedFlashcards,
        flashcardTitle: capturedFlashcardTitle,
        flashcardPackage: FlashcardPackage(
          indices: allResults.map((r) => r.index).toList(),
          studyGoal: userQuery,
        ),
        flashcardMode: settings.flashcardMode,
        chartGeneratorMode: settings.chartGeneratorMode,
        interactiveCanvasMode: settings.interactiveCanvasMode,
        canvasHtml: capturedCanvasHtml,
        steps: messages.sublist(newStepsStartIndex),
      );
    }

    return ResearchResult(
      noInfoFound: true,
      noInfoReason: 'I have reached the maximum research depth without finding specific details in the library to answer your query.',
      steps: messages.sublist(newStepsStartIndex),
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
5. **Specialized Delegation**: If the gathered info suits a specialized tool (e.g., chart generator, coding, flashcards), call that tool. Rely on each tool's name and description for its specific use-case.
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
            .replaceAll(chartMandate, '')
            .replaceAll(codeMandate, '')
            .replaceAll(flashcardMandate, '')
            .replaceAll(canvasMandate, '')
            .replaceAll('\n\nUser Query: ', '')
            .trim();
        buffer.write('Query: $cleanQuery');
      } else if (m.role == domain.MessageRole.assistant) {
        if (m.text.trim().isEmpty) continue; // Skip empty assistant messages (placeholders)
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
