import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../services/ai/i_ai_service.dart';
import '../../../../core/services/openai_service.dart';
import '../../../../core/services/document_processor.dart';

final brainstormOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final processor = ref.watch(documentProcessorProvider);
  return BrainstormOrchestrator(aiService: aiService, processor: processor);
});

class BrainstormOrchestrator {
  final IAiService aiService;
  final DocumentProcessor processor;

  BrainstormOrchestrator({required this.aiService, required this.processor});

  Stream<ChatStreamChunk> streamBrainstorm({
    required List<ChatMessage> history,
    required String query,
    List<PlatformFile>? attachments,
  }) async* {
    dynamic content;

    if (attachments != null && attachments.isNotEmpty) {
      final parts = <ContentPart>[];
      
      for (final file in attachments) {
        if (file.path == null) continue;
        
        final extension = file.extension?.toLowerCase();
        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
        
        if (isImage) {
          final bytes = await File(file.path!).readAsBytes();
          parts.add(ImagePart(base64Encode(bytes), mimeType: 'image/${extension == 'jpg' ? 'jpeg' : extension}'));
        } else {
          // Use robust byte-based extraction with the known extension
          final bytes = await File(file.path!).readAsBytes();
          final extractedText = await processor.extractTextFromBytes(bytes, extension ?? '');
          if (extractedText.isNotEmpty) {
            parts.add(TextPart('--- Attached File: ${file.name} ---\n$extractedText\n---\n\n'));
          }
        }
      }
      
      // Add the user prompt last so the model sees the context first
      parts.add(TextPart(query));
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
    return r'''You are Sift's Assistant.

### Your Mission:
- Help the user brainstorm ideas, solve problems, or explore topics using your broad internal knowledge.
- Be creative, analytical, and helpful.
''';
  }
}
