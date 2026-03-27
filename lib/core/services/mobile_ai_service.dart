import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/ai_models.dart';
import '../../services/ai/i_ai_service.dart';
import '../../core/services/model_platform_service.dart';
import '../../src/features/chat/presentation/controllers/settings_controller.dart';

final mobileAiServiceProvider = Provider<IAiService>((ref) => MobileAiService(ref));

/// A unified AI service for on-device LiteRT inference.
/// Implements [IAiService] so it can be used interchangeably with [OpenAiService].
///
/// Handles:
/// - Prompt serialization from ChatMessage list to a single string
/// - 2-pair (4 message) sliding window for context management
/// - Native bridge via [ModelPlatformService] for streaming responses
class MobileAiService implements IAiService {
  final Ref _ref;

  MobileAiService(this._ref);

  /// Maximum number of history messages to include (2 pairs = 4 messages).
  static const int _maxHistoryMessages = 4;

  @override
  Stream<ChatStreamChunk> streamChat(List<ChatMessage> messages, {bool Function()? isCanceled}) async* {
    final modelPlatform = _ref.read(modelPlatformServiceProvider);

    // 1. Separate system instruction from conversation messages
    String? systemInstruction;
    final conversationMessages = <ChatMessage>[];

    for (final msg in messages) {
      if (msg.role == ChatRole.system) {
        systemInstruction = (systemInstruction ?? '') + (msg.content is String ? msg.content as String : '');
      } else {
        conversationMessages.add(msg);
      }
    }

    // 2. Apply sliding window: keep only the last _maxHistoryMessages
    final windowedMessages = conversationMessages.length > _maxHistoryMessages
        ? conversationMessages.sublist(conversationMessages.length - _maxHistoryMessages)
        : conversationMessages;

    // 3. Serialize conversation into a single prompt string
    final prompt = _serializeToPrompt(windowedMessages);

    debugPrint('==== MOBILE AI SERVICE ====');
    debugPrint('SYSTEM: ${systemInstruction != null ? systemInstruction.substring(0, systemInstruction.length.clamp(0, 200)) : 'null'}...');
    debugPrint('HISTORY WINDOW: ${windowedMessages.length} messages (from ${conversationMessages.length} total)');
    debugPrint('PROMPT LENGTH: ${prompt.length} chars');
    debugPrint('===========================');

    // 4. Reset native conversation state to prevent double-history
    await modelPlatform.resetConversation();

    // 5. Stream from native layer
    final completer = Completer<void>();
    String accumulatedContent = '';

    // Use a StreamController to bridge the listener-based native API to async* yield.
    final controller = StreamController<ChatStreamChunk>();

    StreamSubscription? sub;
    sub = modelPlatform.responseStream.listen((event) {
      // Check cancellation on every incoming token
      if (isCanceled != null && isCanceled()) {
        sub?.cancel();
        modelPlatform.cancelGeneration(); // interrupt native engine
        if (!controller.isClosed) controller.close();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      final type = event['type'] as String?;
      final text = event['text'] as String?;

      if (type == 'partial' && text != null) {
        if (text.length > accumulatedContent.length && text.startsWith(accumulatedContent)) {
          final delta = text.substring(accumulatedContent.length);
          accumulatedContent = text;
          if (!controller.isClosed) controller.add(ChatStreamChunk(content: delta));
        } else {
          accumulatedContent += text;
          if (!controller.isClosed) controller.add(ChatStreamChunk(content: text));
        }
      } else if (type == 'done') {
        sub?.cancel();
        if (!controller.isClosed) controller.close();
        if (!completer.isCompleted) completer.complete();
      } else if (type == 'error') {
        sub?.cancel();
        final error = event['error'] ?? 'Unknown native error';
        if (!controller.isClosed) {
          controller.addError(Exception(error));
          controller.close();
        }
        if (!completer.isCompleted) completer.completeError(Exception(error));
      }
    });

    // Fire the native generation
    await modelPlatform.generateResponse(
      prompt,
      systemInstruction: systemInstruction,
    );

    // Yield chunks as they arrive from the native bridge
    yield* controller.stream;

    // Wait for native completion or cancellation
    await completer.future;
  }



  /// Serializes a list of [ChatMessage] into a single prompt string.
  /// Uses a simple role-prefixed format that works well with instruction-tuned LLMs.
  String _serializeToPrompt(List<ChatMessage> messages) {
    final buffer = StringBuffer();

    for (final msg in messages) {
      final roleLabel = msg.role == ChatRole.user ? 'User' : 'Assistant';
      final content = msg.content is String ? msg.content as String : msg.content.toString();
      buffer.writeln('$roleLabel: $content');
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  @override
  Future<ChatMessage> chat(List<ChatMessage> messages, {List<ToolDefinition>? tools, String? toolChoice}) async {
    // Collect all chunks from streamChat into a single response
    final chunks = <String>[];
    await for (final chunk in streamChat(messages)) {
      if (chunk.content != null) chunks.add(chunk.content!);
    }
    return ChatMessage(role: ChatRole.assistant, content: chunks.join());
  }

  @override
  Stream<ChatStreamChunk> streamResponse(String message) {
    return streamChat([ChatMessage(role: ChatRole.user, content: message)]);
  }

  @override
  Future<AiConnectionStatus> checkConnection() async {
    final settings = _ref.read(settingsProvider);
    if (settings.isMobileEngineInitialized) {
      return AiConnectionStatus.ok;
    }
    return AiConnectionStatus.unreachable;
  }
}
