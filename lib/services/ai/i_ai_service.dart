import '../../core/models/ai_models.dart';

abstract class IAiService {
  Future<ChatMessage> chat(List<ChatMessage> messages, {List<ToolDefinition>? tools, String? toolChoice});
  Stream<String> streamChat(List<ChatMessage> messages);
  Stream<String> streamResponse(String message);
  Future<bool> checkConnection();
}
