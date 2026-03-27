import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/message.dart' as domain;
import 'package:sift_app/core/storage/sift_database.dart';
import 'package:sift_app/core/storage/database_provider.dart';
import 'package:sift_app/src/features/orchestrator/domain/research_orchestrator.dart';
import 'package:sift_app/src/features/orchestrator/domain/chat_orchestrator.dart';
import 'package:sift_app/src/features/orchestrator/domain/brainstorm_orchestrator.dart';
import 'package:sift_app/src/features/orchestrator/domain/graph_generator_orchestrator.dart';
import 'package:sift_app/src/features/chat/presentation/controllers/workbench_controller.dart';
import 'package:sift_app/src/features/chat/presentation/controllers/settings_controller.dart';
import 'package:sift_app/core/models/ai_models.dart' as ai;
import 'package:sift_app/core/services/openai_service.dart';
import 'package:sift_app/core/services/embedding_service.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class ChatState {
  final bool isLoading;
  final List<domain.Message> messages;
  final String? error;
  final int? conversationId;
  final String? researchStatus;
  final bool isConnectionValid;
  final String? connectionError;


  const ChatState({
    this.isLoading = false,
    this.messages = const [],
    this.error,
    this.conversationId,
    this.researchStatus,
    this.isConnectionValid = true,
    this.connectionError,
  });

  ChatState copyWith({
    bool? isLoading,
    List<domain.Message>? messages,
    String? error,
    int? conversationId,
    String? researchStatus,
    bool? isConnectionValid,
    String? connectionError,
    bool? isBrainstormMode,
    bool clearConversationId = false,
    bool clearResearchStatus = false,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      error: error,
      conversationId: clearConversationId ? null : (conversationId ?? this.conversationId),
      researchStatus: clearResearchStatus ? null : (researchStatus ?? this.researchStatus),
      isConnectionValid: isConnectionValid ?? this.isConnectionValid,
      connectionError: connectionError ?? this.connectionError,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  // ignore: unused_field
  final AppDatabase _db;
  final Ref _ref;
  StreamSubscription<List<Message>>? _messagesSubscription;
  bool _isAiProcessing = false;
  bool _isCanceled = false;

  ChatController(this._db, this._ref) : super(const ChatState()) {
    // Initial check
    checkAiConnection();
    
    // Watch for settings changes to re-verify connectivity and sync Brainstorm Mode
    _ref.listen<SettingsState>(settingsProvider, (previous, next) {
      final urlChanged = previous?.llamaServerUrl != next.llamaServerUrl;
      final modelChanged = previous?.chatModel != next.chatModel;
      final serverStarted = previous?.isServerRunning == false && next.isServerRunning == true;
      final modelsLoaded = previous?.isLoadingModels == true && next.isLoadingModels == false;

      if (urlChanged || modelChanged || serverStarted || modelsLoaded) {
        checkAiConnection();
      }

      // Safeguard: If we are on mobile internal, we must NOT be in research mode.
      if (next.isMobileInternal && next.aiMode == AiMode.research) {
        // Use Future.microtask to avoid state mutation during the listener callback
        Future.microtask(() {
          _ref.read(settingsProvider.notifier).updateAiMode(AiMode.lite);
        });
      }
    });
  }

  Future<void> checkAiConnection() async {
    final settings = _ref.read(settingsProvider);
    final aiService = _ref.read(aiServiceProvider);
    
    final isMobileInternal = (Platform.isAndroid || Platform.isIOS) && settings.backendType == BackendType.internal;

    if (isMobileInternal) {
      // For mobile internal, "connected" means initialized or at least configured
      final isReady = settings.isMobileEngineInitialized && settings.isMobileEmbedderInitialized;
      state = state.copyWith(
        isConnectionValid: true, // we don't show a red "unreachable" banner for local mobile AI
        connectionError: isReady ? null : "Mobile AI engines not initialized. Please check settings.",
      );
      return;
    }

    // Suppress "unreachable" error if internal server is explicitly starting up or loading models.
    // This prevents the red banner from flashing during the initial 5s boot delay.
    if (settings.backendType == BackendType.internal && settings.isServerRunning) {
      if (settings.availableModels.isEmpty || settings.isLoadingModels) {
        state = state.copyWith(
          isConnectionValid: true,
          connectionError: null,
        );
        return;
      }
    }

    final status = await aiService.checkConnection();
    
    switch (status) {
      case ai.AiConnectionStatus.ok:
        state = state.copyWith(isConnectionValid: true, connectionError: null);
        break;
      case ai.AiConnectionStatus.loading:
        state = state.copyWith(
          isConnectionValid: false, 
          connectionError: "AI Server is still loading the model. Please wait a moment and try again."
        );
        break;
      case ai.AiConnectionStatus.unreachable:
        state = state.copyWith(
          isConnectionValid: false, 
          connectionError: "AI Server is unreachable. Please check your settings or ensure the server is running."
        );
        break;
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void newChat() {
    _messagesSubscription?.cancel();
    state = state.copyWith(
      clearConversationId: true,
      clearResearchStatus: true,
      messages: [],
      error: null,
    );
  }

  Future<void> loadConversation(int conversationId) async {
    _messagesSubscription?.cancel();
    state = state.copyWith(
      isLoading: true, 
      conversationId: conversationId,
      clearResearchStatus: true,
    );
    
    try {
      // 1. Load conversation metadata to restore mode
      final conv = await _db.getConversationById(conversationId);
      if (conv != null && conv.metadata != null) {
        try {
          // We load common metadata here, but we ignore isBrainstormMode 
          // because it is now a global sticky setting.
          // We still keep the metadata loading for future per-chat properties.
        } catch (e) {
          debugPrint("Error parsing conversation metadata: $e");
        }
      }

      _messagesSubscription = _db.watchMessages(conversationId).listen((messages) {
        final domainMessages = messages.map((m) => domain.Message(
          id: m.uuid,
          text: m.content,
          role: _parseRole(m.role),
          timestamp: m.createdAt,
          lastUpdatedAt: m.lastUpdatedAt,
          reasoning: m.reasoning,
          citations: m.citations != null ? (jsonDecode(m.citations!) as Map<String, dynamic>) : null,
          metadata: m.metadata != null ? (jsonDecode(m.metadata!) as Map<String, dynamic>) : null,
        )).toList();
        
        state = state.copyWith(
          isLoading: _isAiProcessing ? state.isLoading : false,
          messages: domainMessages,
        );
      });
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }


  Future<void> deleteConversation(int id) async {
    await _db.deleteConversation(id);
    if (state.conversationId == id) {
      newChat();
    }
  }

  Future<void> deleteMessage(String uuid) async {
    final dbMsgs = await _db.watchMessages(state.conversationId!).first;
    final msgIndex = dbMsgs.indexWhere((m) => m.uuid == uuid);
    if (msgIndex == -1) return;

    final msg = dbMsgs[msgIndex];
    await _db.softDeleteMessage(msg.id);

    // If deleting a user message, also delete the subsequent assistant response (the "pair")
    if (msg.role == 'user' && msgIndex + 1 < dbMsgs.length) {
      final nextMsg = dbMsgs[msgIndex + 1];
      if (nextMsg.role == 'assistant') {
        await _db.softDeleteMessage(nextMsg.id);
      }
    }
  }

  Future<void> editMessage(String uuid, String newText, int? activeCollectionId, {bool resend = true}) async {
    if (state.isLoading) return;

    final dbMsgs = await _db.watchMessages(state.conversationId!).first;
    final msg = dbMsgs.firstWhere((m) => m.uuid == uuid);

    // 1. Update user message content and mark as edited
    final metadata = Map<String, dynamic>.from(msg.metadata != null ? jsonDecode(msg.metadata!) : {});
    metadata['is_edited'] = true;
    
    await _db.updateMessageContent(msg.id, newText);
    await _db.updateMessageMetadata(msg.id, metadata: jsonEncode(metadata));

    if (!resend) return;

    // 2. Clear subsequent AI responses in this turn (if any) or find existing placeholder
    // For simplicity, we find the message immediately AFTER this one. If it's an assistant message, we regenerate it.
    final nextMsgIndex = dbMsgs.indexWhere((m) => m.sortOrder > msg.sortOrder);
    if (nextMsgIndex != -1 && dbMsgs[nextMsgIndex].role == 'assistant') {
      await regenerateResponse(dbMsgs[nextMsgIndex].uuid, activeCollectionId);
    } else {
      // No assistant message to regenerate? Create one.
      await _db.insertMessage(
        conversationId: state.conversationId!,
        role: 'assistant',
        content: 'Refining memory...',
        sortOrder: msg.sortOrder + 1,
      );
      // Now regenerate (lazy way to reuse logic)
      final updatedMsgs = await _db.watchMessages(state.conversationId!).first;
      final newAssistant = updatedMsgs.firstWhere((m) => m.sortOrder == msg.sortOrder + 1);
      await regenerateResponse(newAssistant.uuid, activeCollectionId);
    }
  }

  Future<void> regenerateResponse(String assistantUuid, int? activeCollectionId) async {
    if (state.isLoading) return;

    final dbMsgs = await _db.watchMessages(state.conversationId!).first;
    final assistantMsg = dbMsgs.firstWhere((m) => m.uuid == assistantUuid);

    // Find the user message associated with this response
    final userMsg = await _db.getMessageBefore(state.conversationId!, assistantMsg.sortOrder);
    if (userMsg == null || userMsg.role != 'user') {
      state = state.copyWith(error: "Cannot regenerate: No preceding user prompt found.");
      return;
    }

    // Clear assistant content/metadata
    await _db.clearMessageMetadata(assistantMsg.id);

    // Sliced history for context isolation (only messages strictly before this assistant message)
    final slicedDomainMessages = state.messages.where((m) {
      final dbMatch = dbMsgs.firstWhere((dbm) => dbm.uuid == m.id);
      return dbMatch.sortOrder < assistantMsg.sortOrder;
    }).toList();

    _isAiProcessing = true;
    _isCanceled = false;
    state = state.copyWith(isLoading: true, error: null);

    // Extract attachments from user message metadata if they exist
    List<PlatformFile>? attachments;
    if (userMsg.metadata != null) {
      try {
        final Map<String, dynamic> metadata = jsonDecode(userMsg.metadata!);
        if (metadata['attachments'] != null) {
          attachments = (metadata['attachments'] as List).map((a) {
            return PlatformFile(
              name: a['name'] ?? 'file',
              path: a['path'],
              size: a['size'] ?? 0,
              identifier: a['extension'],
            );
          }).toList();
        }
      } catch (e) {
        debugPrint("Error parsing attachment metadata for regeneration: $e");
      }
    }

    try {
      await _processAiResponse(
        query: userMsg.content,
        activeCollectionId: activeCollectionId,
        placeholderMessage: assistantMsg,
        currentMessageId: userMsg.uuid,
        messageIdForPruning: userMsg.id,
        historyOverride: slicedDomainMessages,
        attachments: attachments,
      );
    } catch (e) {
       state = state.copyWith(isLoading: false, error: "Regeneration failed: $e");
    } finally {
      _isAiProcessing = false;
      state = state.copyWith(isLoading: false, clearResearchStatus: true);
    }
  }

  Future<void> sendMessage(String text, int? activeCollectionId, {List<PlatformFile>? attachments}) async {
    if (state.isLoading && text.trim().isEmpty && (attachments == null || attachments.isEmpty)) return;
    if (state.isLoading) return;
    if (text.trim().isEmpty && (attachments == null || attachments.isEmpty)) return;

    // 1. Ensure conversation exists
    int? conversationId = state.conversationId;
    if (conversationId == null) {
      if (activeCollectionId == null) {
        state = state.copyWith(error: "No active collection selected");
        return;
      }
      
      try {
        final title = text.length > 30 ? '${text.substring(0, 30)}...' : text;
        
        final newConv = await _db.createConversation(
          activeCollectionId,
          title,
        );
        conversationId = newConv.id;
        
        // Start watching the new conversation
        loadConversation(conversationId);
      } catch (e) {
        state = state.copyWith(error: "Failed to create conversation: $e");
        return;
      }
    }

    final id = conversationId;
    _isAiProcessing = true;
    _isCanceled = false;
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final maxSortOrder = await _db.getMaxSortOrder(id);

      // 3. User Message
      final metadata = attachments != null && attachments.isNotEmpty
          ? jsonEncode({
              'attachments': attachments.map((a) => {
                'name': a.name,
                'path': a.path,
                'size': a.size,
                'extension': a.extension,
              }).toList(),
            })
          : null;

      final userMessage = await _db.insertMessage(
        conversationId: id,
        role: 'user',
        content: text,
        sortOrder: maxSortOrder + 1,
        metadata: metadata,
      );

      // 4. Placeholder Assistant Message
      final placeholderMessage = await _db.insertMessage(
        conversationId: id,
        role: 'assistant',
        content: '',
        sortOrder: maxSortOrder + 2,
      );

      // 3. Process AI loop
      _isCanceled = false;
      await _processAiResponse(
        query: text,
        activeCollectionId: activeCollectionId,
        placeholderMessage: placeholderMessage,
        currentMessageId: userMessage.uuid,
        messageIdForPruning: userMessage.id,
        attachments: attachments,
      );

    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Failed to process research: $e", clearResearchStatus: true);
    } finally {
      _isAiProcessing = false;
      state = state.copyWith(isLoading: false, clearResearchStatus: true);
    }
  }

  Future<void> _processAiResponse({
    required String query,
    required int? activeCollectionId,
    required dynamic placeholderMessage, // Message object from DB
    required String currentMessageId,
    List<domain.Message>? historyOverride,
    int? messageIdForPruning,
    List<PlatformFile>? attachments,
  }) async {
    try {
      final settings = _ref.read(settingsProvider);
      final isMobileInternal = (Platform.isAndroid || Platform.isIOS) && settings.backendType == BackendType.internal;

      if (!isMobileInternal) {
        await checkAiConnection();
        if (!state.isConnectionValid) {
          throw Exception(state.connectionError ?? "AI Server is unreachable.");
        }
      } else {
        if (!settings.isMobileEngineInitialized || !settings.isMobileEmbedderInitialized) {
          throw Exception("Mobile AI engines are not initialized. Please check settings.");
        }
      }
      final researchOrchestrator = _ref.read(researchOrchestratorProvider);
      final chatOrchestrator = _ref.read(chatOrchestratorProvider);

      // Precise Filtering:
      // Exclude the current user message and the assistant placeholder from history.
      // This prevents the current query from being duplicated in the LLM payload.
      final effectiveHistory = (historyOverride ?? state.messages)
          .where((m) => 
            m.id != placeholderMessage.uuid && 
            m.id != currentMessageId
          )
          .toList();

      final chatHistory = await chatOrchestrator.buildHistory(
        effectiveHistory,
        limit: settings.aiMode == AiMode.brainstorm ? null : 8,
      );

      // --- BRANCH: Brainstorm Mode (works on all platforms via unified aiService) ---
      if (settings.aiMode == AiMode.brainstorm) {
        final brainstormOrchestrator = _ref.read(brainstormOrchestratorProvider);
        state = state.copyWith(clearResearchStatus: true); // Was "Brainstorming..."
        
        String finalContent = '';
        String finalReasoning = '';
        final stream = brainstormOrchestrator.streamBrainstorm(
          history: chatHistory,
          query: query,
          attachments: attachments,
          isCanceled: () => _isCanceled,
        );

        bool isFirstToken = true;
        await for (final chunk in stream) {
          if (_isCanceled) break;
          if (isFirstToken && (chunk.reasoningContent != null || chunk.content != null)) {
            isFirstToken = false;
            await _db.updateMessageContent(placeholderMessage.id, '');
          }
          if (chunk.reasoningContent != null) {
            finalReasoning += chunk.reasoningContent!;
            _db.updateMessageReasoning(placeholderMessage.id, finalReasoning);
          }
          if (chunk.content != null) {
            finalContent += chunk.content!;
            _db.updateMessageContent(placeholderMessage.id, finalContent);
          }
        }

        state = state.copyWith(isLoading: false, clearResearchStatus: true);
        return;
      }

      // --- BRANCH: RAG Research Mode ---
      final researchHistory = researchOrchestrator.buildHistory(effectiveHistory);

      state = state.copyWith(clearResearchStatus: true); // Was "Searching..." / "Initializing research..."

      // --- BRANCH: Lite-RAG vs Desktop Research Orchestrator ---
      if (isMobileInternal || settings.aiMode == AiMode.lite) {
        await _handleLiteRag(query, activeCollectionId!, placeholderMessage, chatHistory);
        return;
      }

      // --- NEW: Context Sanitization for Workbench ---
      final workbench = _ref.read(workbenchProvider);
      final activeTab = workbench.activeTab;
      String? currentGraphSchema;
      String? currentCodeContext;
      String? currentCodeTitle;
      List<ai.Flashcard>? currentFlashcards;
      
      if (activeTab != null) {
        // Block "Stale" context: If the active tab belongs to the message we are regenerating
        if (activeTab.id.contains(placeholderMessage.uuid)) {
          debugPrint('Sifting isolation: Blocking stale workbench tab ${activeTab.id}');
        } else {
          if (activeTab.type == WorkbenchTabType.graph) {
            currentGraphSchema = activeTab.metadata?['schema'];
          } else if (activeTab.type == WorkbenchTabType.code) {
            currentCodeContext = activeTab.metadata?['code'];
            currentCodeTitle = activeTab.title;
          } else if (activeTab.type == WorkbenchTabType.flashcards) {
            final dynamic cardsRaw = activeTab.metadata?['cards'];
            if (cardsRaw is List) {
              currentFlashcards = cardsRaw.map((c) => ai.Flashcard.fromJson(c as Map<String, dynamic>)).toList();
            }
          }
        }
      }

      String? currentCanvasHtml;
      if (activeTab?.type == WorkbenchTabType.interactiveCanvas) {
        currentCanvasHtml = activeTab?.metadata?['htmlContent'] as String?;
      }

      // 5. Research AI Step
      final researchResult = await researchOrchestrator.research(
        collectionId: activeCollectionId!,
        historicalContext: researchHistory,
        userQuery: query,
        currentGraphSchema: currentGraphSchema,
        currentCode: currentCodeContext,
        currentCodeTitle: currentCodeTitle,
        currentFlashcards: currentFlashcards,
        currentCanvasHtml: currentCanvasHtml,
        onStatusUpdate: (status) => state = state.copyWith(researchStatus: status),
        isCanceled: () => _isCanceled,
      );

      if (researchResult.canceled || _isCanceled) {
        state = state.copyWith(isLoading: false, researchStatus: 'Canceled');
        return;
      }

      if (researchResult.noInfoFound) {
        // AI found nothing. Stop and prune this turn.
        final metadata = {
          'exclude_from_history': true,
          'research_steps': researchResult.steps?.map((s) => s.toJson()).toList() ?? [],
        };

        // Mark user query as pruned too
        if (messageIdForPruning != null) {
          await _db.updateMessageMetadata(messageIdForPruning, metadata: jsonEncode({'exclude_from_history': true}));
        }
        
        // Update assistant placeholder
        final reason = researchResult.noInfoReason ?? 'No information found about that in the current library.';
        await _db.updateMessageContent(placeholderMessage.id, reason);
        await _db.updateMessageMetadata(placeholderMessage.id, metadata: jsonEncode(metadata));

        state = state.copyWith(isLoading: false, clearResearchStatus: true);
        return;
      }

      if (researchResult.graphSchema != null) {
      // --- NEW: Handle Graph Generation (from intermediate step) -----
      final schemaStr = researchResult.graphSchema!;
      String? parsedTitle;
      
      try {
        final Map<String, dynamic> schema = jsonDecode(schemaStr);
        parsedTitle = schema['title'] as String?;
      } catch (e) {
        debugPrint('Failed to parse graph title: $e');
      }

      // Auto-open the tab
      _ref.read(workbenchProvider.notifier).addTab(
        WorkbenchTab(
          id: 'graph_${placeholderMessage.uuid}',
          title: parsedTitle ?? 'Graph',
          icon: Icons.hub_rounded,
          type: WorkbenchTabType.graph,
          metadata: {'schema': schemaStr},
        ),
      );
    }

    if (researchResult.codeSnippet != null) {
      // Auto-open the code tab
      _ref.read(workbenchProvider.notifier).addTab(
        WorkbenchTab(
          id: 'code_${placeholderMessage.uuid}',
          title: researchResult.codeTitle ?? 'Generated Code',
          icon: Icons.code_rounded,
          type: WorkbenchTabType.code,
          metadata: {
            'code': researchResult.codeSnippet,
            'language': researchResult.codeLanguage ?? 'plaintext',
          },
        ),
      );
    }

    if (researchResult.flashcardResult != null) {
      // Auto-open the flashcard tab
      _ref.read(workbenchProvider.notifier).addTab(
        WorkbenchTab(
          id: 'cards_${placeholderMessage.uuid}',
          title: researchResult.flashcardTitle ?? 'Study Deck',
          icon: Icons.sports_esports_outlined,
          type: WorkbenchTabType.flashcards,
          metadata: {
            'cards': researchResult.flashcardResult!.map((c) => c.toJson()).toList(),
          },
        ),
      );
    }

    if (researchResult.canvasHtml != null) {
      // Auto-open the interactive canvas tab
      _ref.read(workbenchProvider.notifier).addTab(
        WorkbenchTab(
          id: 'canvas_${placeholderMessage.uuid}',
          title: 'Interactive Canvas',
          icon: Icons.auto_awesome_mosaic_rounded,
          type: WorkbenchTabType.interactiveCanvas,
          metadata: {
            'htmlContent': researchResult.canvasHtml,
          },
        ),
      );
    }
      if (researchResult.package != null) {
        // 1. Build Citation Metadata Early (so citations work DURING streaming)
        final citationData = <String, dynamic>{};
        for (final index in researchResult.package!.indices) {
          final res = researchOrchestrator.registry.getResult(index);
          if (res != null) {
            citationData[index.toString()] = {
              'documentId': res.documentId,
              'sourceTitle': res.sourceTitle,
              'chunkIndex': res.chunkIndex,
            };
          }
        }
        
        await _db.updateMessageMetadata(
          placeholderMessage.id, 
          citations: jsonEncode(citationData),
        );

        state = state.copyWith(clearResearchStatus: true); // Was "Synthesizing..."

        
        String finalContent = '';
        String finalReasoning = '';
        final stream = chatOrchestrator.streamSynthesize(
          originalQuery: query,
          conversation: chatHistory,
          package: researchResult.package!,
          registry: researchOrchestrator.registry,
          graphSchema: researchResult.graphSchema,
          codeSnippet: researchResult.codeSnippet,
          flashcardTitle: researchResult.flashcardTitle,
          flashcardCount: researchResult.flashcardResult?.length,
          canvasHtml: researchResult.canvasHtml,
        );

        bool isFirstToken = true;
        await for (final chunk in stream) {
          if (_isCanceled) break;
          if (isFirstToken && (chunk.reasoningContent != null || chunk.content != null)) {
            isFirstToken = false;
            await _db.updateMessageContent(placeholderMessage.id, '');
          }
          if (chunk.reasoningContent != null) {
            finalReasoning += chunk.reasoningContent!;
            _db.updateMessageReasoning(placeholderMessage.id, finalReasoning);
          }
          if (chunk.content != null) {
            finalContent += chunk.content!;
            _db.updateMessageContent(placeholderMessage.id, finalContent);
          }
        }

        // --- Persist Research Steps & Metadata ---
        final List<ai.ChatMessage> completeSteps = List.from(researchResult.steps ?? []);
        
        // Add final tool outcome for history tracking
        try {
          final lastAssistantWithCalls = completeSteps.lastWhere(
            (s) => s.role == ai.ChatRole.assistant && s.toolCalls != null && s.toolCalls!.any((tc) => tc.function.name == 'finalize_research_response'),
          );
          
          final delegateCall = lastAssistantWithCalls.toolCalls!.firstWhere(
            (tc) => tc.function.name == 'finalize_research_response',
          );
          
          completeSteps.add(ai.ChatMessage(
            role: ai.ChatRole.tool,
            content: finalContent,
            toolCallId: delegateCall.id,
            name: 'finalize_research_response',
          ));
        } catch (e) { /* skip */ }

        final metadata = <String, dynamic>{
          'research_steps': completeSteps.map((s) => s.toJson()).toList(),
          if (researchResult.graphSchema != null) 'graph_schema': researchResult.graphSchema,
          if (researchResult.codeSnippet != null) 'code_snippet': researchResult.codeSnippet,
          if (researchResult.codeTitle != null) 'code_title': researchResult.codeTitle,
          if (researchResult.canvasHtml != null) 'canvas_html': researchResult.canvasHtml,
          if (researchResult.flashcardResult != null) 'cards': researchResult.flashcardResult,
          if (researchResult.flashcardTitle != null) 'flashcard_title': researchResult.flashcardTitle,
        };

        await _db.updateMessageMetadata(
          placeholderMessage.id, 
          metadata: jsonEncode(metadata),
        );
      } else if (researchResult.graphPackage != null) {
        // Fallback for legacy terminal visual calls (if any remain)
        final graphGeneratorOrchestrator = _ref.read(graphGeneratorOrchestratorProvider);
        final graphResult = await graphGeneratorOrchestrator.generateGraph(
          package: researchResult.graphPackage!,
          registry: researchOrchestrator.registry,
        );

        final schema = graphResult.schema;
        String tabTitle = 'Graph';
        try {
          final Map<String, dynamic> parsed = jsonDecode(schema);
          final title = parsed['title'] as String?;
          if (title != null && title.isNotEmpty) tabTitle = title;
        } catch (_) {}

        await _db.updateMessageContent(placeholderMessage.id, 'Graph generated based on research data.');
        
        final metadata = <String, dynamic>{
          'graph_schema': schema,
          'research_steps': researchResult.steps?.map((s) => s.toJson()).toList() ?? [],
        };
        
        await _db.updateMessageMetadata(placeholderMessage.id, metadata: jsonEncode(metadata));

        _ref.read(workbenchProvider.notifier).addTab(
          WorkbenchTab(
            id: 'graph_${placeholderMessage.uuid}',
            title: tabTitle,
            icon: Icons.hub_rounded,
            type: WorkbenchTabType.graph,
            metadata: {'schema': schema},
          ),
        );
      } else {
        // Case: No synthesizer AND no visualizer (maybe Research AI just chatted)
        if (researchResult.output != null) {
           await _db.updateMessageContent(placeholderMessage.id, researchResult.output!.content);
        } else {
           await _db.updateMessageContent(placeholderMessage.id, 'I couldn\'t find enough specific information to answer that accurately.');
        }
      }

      state = state.copyWith(isLoading: false, clearResearchStatus: true);
      
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Failed to process research: $e", clearResearchStatus: true);
    } finally {
      _isAiProcessing = false;
    }
  }

  void stopResponse() {
    _isCanceled = true;
    state = state.copyWith(isLoading: false, researchStatus: 'Stopping...');
  }

  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
  Future<void> _handleLiteRag(
    String query,
    int collectionId,
    Message placeholderMessage,
    List<ai.ChatMessage> history,
  ) async {
    try {
      final chatOrchestrator = _ref.read(chatOrchestratorProvider);
      final aiService = _ref.read(aiServiceProvider);

      // 1. Vector Search
      state = state.copyWith(clearResearchStatus: true);
      final embedService = _ref.read(embeddingServiceProvider);
      final List<List<double>> embeddingResult = await embedService.getEmbeddings([query]);
      final List<double> queryVector = embeddingResult.first;

      state = state.copyWith(clearResearchStatus: true);
      final searchResults = await _db.vectorSearch(
        collectionId: collectionId,
        queryEmbedding: queryVector,
        limit: 3,
      );

      if (searchResults.isEmpty) {
        await _db.updateMessageContent(placeholderMessage.id, "I couldn't find any relevant information in your collection to answer that.");
        return;
      }

      // 2. Prepare Context
      final List<String> contextChunks = [];
      final citationData = <String, dynamic>{};
      
      for (int i = 0; i < searchResults.length; i++) {
        final row = searchResults[i];
        final chunk = row.readTable(_db.documentChunks);
        final doc = row.readTable(_db.documents);
        
        final chunkLabel = '[[Chunk ${i + 1}]]';
        contextChunks.add('$chunkLabel\n${chunk.content}');
        
        citationData[(i + 1).toString()] = {
          'documentId': doc.id,
          'sourceTitle': doc.title,
          'chunkIndex': chunk.index,
        };
      }

      await _db.updateMessageMetadata(
        placeholderMessage.id,
        citations: jsonEncode(citationData),
      );

      // 3. Prompt Construction
      final systemPrompt = chatOrchestrator.buildLiteSystemPrompt();
      final lastTurn = history.length >= 2 ? history.sublist(history.length - 2) : history;
      final combinedUserMessage = chatOrchestrator.buildCombinedMessage(
        contextChunks, 
        query,
        history: lastTurn,
      );

      debugPrint('==== LITE RAG PROMPT ====');
      debugPrint('SYSTEM INSTRUCTION:\n$systemPrompt');
      debugPrint('USER PROMPT:\n$combinedUserMessage');
      debugPrint('========================');

      state = state.copyWith(clearResearchStatus: true);

      // 4. Unified AI Service Generation (works on both mobile and desktop)
      final messages = [
        ai.ChatMessage(role: ai.ChatRole.system, content: systemPrompt),
        ...lastTurn,
        ai.ChatMessage(role: ai.ChatRole.user, content: combinedUserMessage),
      ];

      String finalContent = '';
      String finalReasoning = '';
      final stream = aiService.streamChat(messages, isCanceled: () => _isCanceled);

      await for (final chunk in stream) {
        if (_isCanceled) break;
        if (chunk.reasoningContent != null) {
          finalReasoning += chunk.reasoningContent!;
          _db.updateMessageReasoning(placeholderMessage.id, finalReasoning);
        }
        if (chunk.content != null) {
          finalContent += chunk.content!;
          _db.updateMessageContent(placeholderMessage.id, finalContent);
        }
      }
    } catch (e) {
      _db.updateMessageContent(placeholderMessage.id, "Error: $e");
      rethrow;
    }
  }

  domain.MessageRole _parseRole(String role) {
    switch (role) {
      case 'user': return domain.MessageRole.user;
      case 'assistant': return domain.MessageRole.assistant;
      case 'system': return domain.MessageRole.system;
      case 'tool': return domain.MessageRole.tool;
      default: return domain.MessageRole.user;
    }
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  final db = ref.watch(databaseProvider);
  return ChatController(db, ref);
});
