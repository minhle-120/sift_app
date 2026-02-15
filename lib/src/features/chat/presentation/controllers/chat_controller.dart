import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/message.dart' as domain;
import 'package:sift_app/core/storage/sift_database.dart';
import 'package:sift_app/core/storage/database_provider.dart';
import 'package:sift_app/src/features/orchestrator/domain/research_orchestrator.dart';
import 'package:sift_app/src/features/orchestrator/domain/chat_orchestrator.dart';
import 'package:sift_app/src/features/chat/presentation/controllers/settings_controller.dart';
import 'package:sift_app/core/models/ai_models.dart' as ai;
import 'package:sift_app/core/services/openai_service.dart';

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
    bool clearConversationId = false,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      error: error,
      conversationId: clearConversationId ? null : (conversationId ?? this.conversationId),
      researchStatus: researchStatus ?? this.researchStatus,
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

  ChatController(this._db, this._ref) : super(const ChatState()) {
    // Initial check
    checkAiConnection();
    
    // Watch for settings changes (URL or Model) to re-verify connectivity
    _ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if (previous?.llamaServerUrl != next.llamaServerUrl || 
          previous?.chatModel != next.chatModel) {
        checkAiConnection();
      }
    });
  }

  Future<void> checkAiConnection() async {
    final aiService = _ref.read(aiServiceProvider);
    final isValid = await aiService.checkConnection();
    
    state = state.copyWith(
      isConnectionValid: isValid,
      connectionError: isValid ? null : "AI Server is unreachable. Please check your settings.",
    );
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
      messages: [],
      error: null,
    );
  }

  Future<void> loadConversation(int conversationId) async {
    _messagesSubscription?.cancel();
    state = state.copyWith(isLoading: true, conversationId: conversationId);
    
    try {
      _messagesSubscription = _db.watchMessages(conversationId).listen((messages) {
        final domainMessages = messages.map((m) => domain.Message(
          id: m.uuid,
          text: m.content,
          role: _parseRole(m.role),
          timestamp: m.createdAt,
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

  Future<void> sendMessage(String text, int? activeCollectionId) async {
    if (state.isLoading || text.trim().isEmpty) return;

    // 1. Ensure conversation exists
    int? conversationId = state.conversationId;
    if (conversationId == null) {
      if (activeCollectionId == null) {
        state = state.copyWith(error: "No active collection selected");
        return;
      }
      
      try {
        final title = text.length > 30 ? '${text.substring(0, 30)}...' : text;
        final newConv = await _db.createConversation(activeCollectionId, title);
        conversationId = newConv.id;
        
        // Start watching the new conversation
        loadConversation(conversationId);
      } catch (e) {
        state = state.copyWith(error: "Failed to create conversation: $e");
        return;
      }
    }

    _isAiProcessing = true;
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // 2. Pre-flight connection check (Move inside try-catch to ensure isLoading is reset)
      await checkAiConnection();
      if (!state.isConnectionValid) {
        throw Exception(state.connectionError ?? "AI Server is unreachable.");
      }

      // 3. Prepare Isolated Histories via Orchestrators
      final researchOrchestrator = _ref.read(researchOrchestratorProvider);
      final chatOrchestrator = _ref.read(chatOrchestratorProvider);

      final chatHistory = chatOrchestrator.buildHistory(state.messages);
      final researchHistory = researchOrchestrator.buildHistory(state.messages);

      // 3. User Message
      final userMessage = await _db.insertMessage(
        conversationId: conversationId,
        role: 'user',
        content: text,
        sortOrder: state.messages.length,
      );

      // 4. Placeholder Assistant Message
      final placeholderMessage = await _db.insertMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: 'Researching...',
        sortOrder: state.messages.length + 1,
      );

      state = state.copyWith(researchStatus: 'Initializing research...');

      // 5. Research AI Step
      final researchResult = await researchOrchestrator.research(
        collectionId: activeCollectionId!,
        historicalContext: researchHistory,
        userQuery: text,
        onStatusUpdate: (status) {
          state = state.copyWith(researchStatus: status);
          _db.updateMessageContent(placeholderMessage.id, status);
        },
      );

      if (researchResult.noInfoFound) {
        // AI found nothing. Stop and prune this turn.
        final metadata = {
          'exclude_from_history': true,
          'research_steps': researchResult.steps?.map((s) => s.toJson()).toList() ?? [],
        };

        // Mark user query as pruned too
        await _db.updateMessageMetadata(userMessage.id, metadata: jsonEncode({'exclude_from_history': true}));
        
        // Update assistant placeholder
        final reason = researchResult.noInfoReason ?? 'No information found about that in the current library.';
        await _db.updateMessageContent(placeholderMessage.id, reason);
        await _db.updateMessageMetadata(placeholderMessage.id, metadata: jsonEncode(metadata));

        state = state.copyWith(isLoading: false, researchStatus: null);
        return;
      }

      String finalContent = '';

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

        state = state.copyWith(researchStatus: 'Synthesizing final answer...');
        await _db.updateMessageContent(placeholderMessage.id, 'Synthesizing...');
        
        final stream = chatOrchestrator.streamSynthesize(
          originalQuery: text,
          conversation: chatHistory,
          package: researchResult.package!,
          registry: researchOrchestrator.registry,
        );

        await for (final chunk in stream) {
          finalContent += chunk;
          // Update DB in real-time for UI reactivity
          _db.updateMessageContent(placeholderMessage.id, finalContent);
        }

        // --- NEW: Persist Research Steps ---
        final List<ai.ChatMessage> completeSteps = List.from(researchResult.steps ?? []);
        
        // Find the delegation tool call and add the final message as its result for futureTurns
        try {
          final lastAssistantWithCalls = completeSteps.lastWhere(
            (s) => s.role == ai.ChatRole.assistant && s.toolCalls != null && s.toolCalls!.any((tc) => tc.function.name == 'delegate_to_synthesizer'),
          );
          
          final delegateCall = lastAssistantWithCalls.toolCalls!.firstWhere(
            (tc) => tc.function.name == 'delegate_to_synthesizer',
          );
          
          completeSteps.add(ai.ChatMessage(
            role: ai.ChatRole.tool,
            content: finalContent,
            toolCallId: delegateCall.id,
            name: 'delegate_to_synthesizer',
          ));
        } catch (e) {
          // No delegation found (maybe researcher reached max iterations), skip adding tool result
        }

        final metadata = <String, dynamic>{
          'research_steps': completeSteps.map((s) => s.toJson()).toList(),
        };

        await _db.updateMessageMetadata(
          placeholderMessage.id, 
          metadata: jsonEncode(metadata),
        );
      } else {
        await _db.updateMessageContent(placeholderMessage.id, 'I couldn\'t find enough specific information to answer that accurately.');
        throw Exception('I couldn\'t find enough specific information to answer that accurately.');
      }

      state = state.copyWith(isLoading: false, researchStatus: null);
      
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Failed to process research: $e", researchStatus: null);
    } finally {
      _isAiProcessing = false;
    }
  }

  void stopResponse() {
    state = state.copyWith(isLoading: false);
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
