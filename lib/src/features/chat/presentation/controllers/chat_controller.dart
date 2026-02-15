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
          isLoading: false,
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
    if (text.trim().isEmpty) return;

    // 0. Pre-flight connection check
    await checkAiConnection();
    if (!state.isConnectionValid) {
      state = state.copyWith(error: state.connectionError);
      return;
    }

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

    state = state.copyWith(isLoading: true);
    
    try {
      // 2. Prepare Histories
      
      // A. Chat History (User-visible messages ONLY for the Synthesizer)
      final List<ai.ChatMessage> chatHistory = state.messages.map((m) => ai.ChatMessage(
        role: m.role == domain.MessageRole.user ? ai.ChatRole.user : ai.ChatRole.assistant,
        content: m.text,
      )).toList();

      // B. Research History (Internal ReAct steps for the Researcher)
      final List<ai.ChatMessage> researchHistory = [];
      for (final m in state.messages) {
        if (m.metadata != null && m.metadata!.containsKey('research_steps')) {
          final stepsJson = m.metadata!['research_steps'] as List<dynamic>;
          for (final step in stepsJson) {
            researchHistory.add(ai.ChatMessage.fromJson(step as Map<String, dynamic>));
          }
        } else {
          researchHistory.add(ai.ChatMessage(
            role: m.role == domain.MessageRole.user ? ai.ChatRole.user : ai.ChatRole.assistant,
            content: m.text,
          ));
        }
      }

      // 3. Insert User Message
      await _db.insertMessage(
        conversationId: conversationId,
        role: 'user',
        content: text,
        sortOrder: state.messages.length,
      );

      state = state.copyWith(researchStatus: 'Initializing research...');

      // 4. Insert Placeholder Assistant Message
      final placeholderMessage = await _db.insertMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: 'Researching...',
        sortOrder: state.messages.length,
      );

      // 5. Research AI Step
      final researchOrchestrator = _ref.read(researchOrchestratorProvider);
      final chatOrchestrator = _ref.read(chatOrchestratorProvider);

      final researchResult = await researchOrchestrator.research(
        collectionId: activeCollectionId!,
        conversation: researchHistory,
        userQuery: text,
        onStatusUpdate: (status) {
          state = state.copyWith(researchStatus: status);
          _db.updateMessageContent(placeholderMessage.id, status);
        },
      );

      ai.ChatMessage finalMessage;

      if (researchResult.package != null) {
        state = state.copyWith(researchStatus: 'Synthesizing final answer...');
        _db.updateMessageContent(placeholderMessage.id, 'Synthesizing final answer...');
        
        finalMessage = await chatOrchestrator.synthesize(
          originalQuery: text,
          conversation: chatHistory,
          package: researchResult.package!,
          registry: researchOrchestrator.registry,
        );

        // Save citation metadata
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
            content: finalMessage.content,
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
          citations: jsonEncode(citationData),
          metadata: jsonEncode(metadata),
        );
      } else {
        await _db.updateMessageContent(placeholderMessage.id, 'I couldn\'t find enough specific information to answer that accurately.');
        throw Exception('I couldn\'t find enough specific information to answer that accurately.');
      }

      // 5. Update Placeholder with Final Message
      await _db.updateMessageContent(placeholderMessage.id, finalMessage.content);

      state = state.copyWith(isLoading: false, researchStatus: null);
      
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Failed to process research: $e", researchStatus: null);
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
