import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/message.dart' as domain;
import 'package:sift_app/core/storage/sift_database.dart';
import 'package:sift_app/core/storage/database_provider.dart';

class ChatState {
  final bool isLoading;
  final List<domain.Message> messages;
  final String? error;
  final int? conversationId;
  final String? researchKeywords;

  const ChatState({
    this.isLoading = false,
    this.messages = const [],
    this.error,
    this.conversationId,
    this.researchKeywords,
  });

  ChatState copyWith({
    bool? isLoading,
    List<domain.Message>? messages,
    String? error,
    int? conversationId,
    String? researchKeywords,
    bool clearConversationId = false,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      error: error,
      conversationId: clearConversationId ? null : (conversationId ?? this.conversationId),
      researchKeywords: researchKeywords ?? this.researchKeywords,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  // ignore: unused_field
  final AppDatabase _db;
  StreamSubscription<List<Message>>? _messagesSubscription;

  ChatController(this._db) : super(const ChatState());

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
      // 2. Insert User Message
      await _db.insertMessage(
        conversationId: conversationId,
        role: 'user',
        content: text,
        sortOrder: state.messages.length,
      );

      // 3. For now, just stop loading. AI integration comes later.
      // The watchMessages stream will update the UI with the new user message.
      state = state.copyWith(isLoading: false);
      
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Failed to send message: $e");
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
  return ChatController(db);
});
