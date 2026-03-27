import '../../core/models/ai_models.dart';

abstract class IAiService {
  Future<ChatMessage> chat(List<ChatMessage> messages, {List<ToolDefinition>? tools, String? toolChoice});
  Stream<ChatStreamChunk> streamChat(List<ChatMessage> messages, {bool Function()? isCanceled});
  Stream<ChatStreamChunk> streamResponse(String message);
  Future<AiConnectionStatus> checkConnection();
}
