import '../../core/models/ai_models.dart';

abstract class IAiService {
  Future<ChatMessage> chat(List<ChatMessage> messages, {List<ToolDefinition>? tools});
  Stream<String> streamResponse(String message);
  Future<bool> checkConnection();
}
