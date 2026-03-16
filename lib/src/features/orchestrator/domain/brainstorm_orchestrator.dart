import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../services/ai/i_ai_service.dart';
import '../../../../core/services/openai_service.dart';

final brainstormOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return BrainstormOrchestrator(aiService: aiService);
});

class BrainstormOrchestrator {
  final IAiService aiService;

  BrainstormOrchestrator({required this.aiService});

  Stream<ChatStreamChunk> streamBrainstorm({
    required List<ChatMessage> history,
    required String query,
    List<PlatformFile>? attachments,
  }) async* {
    dynamic content;

    if (attachments != null && attachments.isNotEmpty) {
      final parts = <ContentPart>[TextPart(query)];
      
      for (final file in attachments) {
        if (file.path == null) continue;
        
        final extension = file.extension?.toLowerCase();
        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
        
        if (isImage) {
          final bytes = await File(file.path!).readAsBytes();
          parts.add(ImagePart(base64Encode(bytes), mimeType: 'image/${extension == 'jpg' ? 'jpeg' : extension}'));
        } else {
          // Try reading as text for context inclusion
          try {
            final text = await File(file.path!).readAsString();
            parts.add(TextPart('\n\n--- Attached File: ${file.name} ---\n$text\n---'));
          } catch (e) {
            // Skip non-text files for now or handle differently
          }
        }
      }
      content = parts;
    } else {
      content = query;
    }

    final messages = [
      ChatMessage(role: ChatRole.system, content: _buildBrainstormSystemPrompt()),
      ...history,
      ChatMessage(role: ChatRole.user, content: content),
    ];

    yield* aiService.streamChat(messages);
  }

  String _buildBrainstormSystemPrompt() {
    return r'''You are Sift's Brainstorming Assistant.

### Your Mission:
- Help the user brainstorm ideas, solve problems, or explore topics using your broad internal knowledge.
- Be creative, analytical, and highly helpful.
''';
  }
}
