import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/services/openai_service.dart';
import '../../../../services/ai/i_ai_service.dart';

class FlashcardPackage {
  final List<int> indices;
  final String studyGoal;

  FlashcardPackage({required this.indices, required this.studyGoal});

  @override
  String toString() => 'FlashcardPackage(indices: $indices, goal: $studyGoal)';
}

class Flashcard {
  final String id;
  final String question;
  final String answer;
  final String? explanation;

  Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    this.explanation,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'answer': answer,
    if (explanation != null) 'explanation': explanation,
  };
}

class FlashcardResult {
  final FlashcardPackage package;
  final List<Flashcard> cards;
  final String title;
  final List<ChatMessage> steps;

  FlashcardResult({
    required this.package,
    required this.cards,
    required this.title,
    required this.steps,
  });
}

final flashcardOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return FlashcardOrchestrator(aiService: aiService);
});

class FlashcardOrchestrator {
  final IAiService aiService;

  FlashcardOrchestrator({required this.aiService});

  Future<FlashcardResult> generateFlashcards({
    required FlashcardPackage package,
    required ChunkRegistry registry,
    String? fullContext,
  }) async {
    // 1. Resolve Chunks
    final List<String> resolvedChunks = [];
    for (final index in package.indices) {
      final res = registry.getResult(index);
      if (res != null) {
        resolvedChunks.add('[[Chunk $index]]\n${res.content}');
      }
    }

    // 2. Build Bundled Message
    final StringBuffer contentBuffer = StringBuffer();

    if (fullContext != null) {
      contentBuffer.writeln('### CONVERSATION HISTORY');
      contentBuffer.writeln(fullContext);
      contentBuffer.writeln();
    }

    contentBuffer.writeln('### FLASHCARD GOAL');
    contentBuffer.writeln(package.studyGoal);
    contentBuffer.writeln();
    contentBuffer.writeln('### INFORMATION CHUNKS');
    contentBuffer.writeln(resolvedChunks.join('\n\n'));

    final messages = [
      ChatMessage(role: ChatRole.system, content: _buildSystemPrompt()),
      ChatMessage(
        role: ChatRole.user,
        content: contentBuffer.toString().trim(),
      ),
    ];

    // 3. Generate Flashcards
    final response = await aiService.chat(messages);
    final jsonResponse = _extractJson(response.content);
    
    String title = 'Flashcard Deck';
    List<Flashcard> cards = [];

    try {
      final data = jsonDecode(jsonResponse);
      if (data is Map) {
        title = data['title'] ?? 'Flashcard Deck';
        if (data['cards'] is List) {
          cards = (data['cards'] as List)
              .map((c) => Flashcard.fromJson(c as Map<String, dynamic>))
              .toList();
        }
      } else if (data is List) {
        // Fallback if AI only returns a list
        cards = data.map((c) => Flashcard.fromJson(c as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      // Basic recovery - might need better error handling
    }

    // 4. Return result
    return FlashcardResult(
      package: package,
      cards: cards,
      title: title,
      steps: [
        ChatMessage(
          role: response.role,
          content: response.content,
          toolCalls: response.toolCalls,
        )
      ],
    );
  }

  String _extractJson(String text) {
    if (text.contains('```json')) {
      final startIndex = text.indexOf('```json') + '```json'.length;
      final endIndex = text.lastIndexOf('```');
      if (endIndex > startIndex) {
        return text.substring(startIndex, endIndex).trim();
      }
    } else if (text.contains('```')) {
      final startIndex = text.indexOf('```') + '```'.length;
      final endIndex = text.lastIndexOf('```');
      if (endIndex > startIndex) {
        return text.substring(startIndex, endIndex).trim();
      }
    }
    return text.trim();
  }

  String _buildSystemPrompt() {
    return '''You are a Learning Scientist and Flashcard Specialist. Your task is to transform research evidence into high-quality, atomic flashcards optimized for long-term retention.

### CORE PRINCIPLES:
1. **The Minimum Information Principle**: Each card should contain only one discrete piece of information. Avoid complex many-to-one relationships. If a concept is complex, break it into multiple cards.
2. **Atomic Questions**: Questions should be clear and concise. 
3. **Clarity over Complexity**: Use simple language unless technical terminology is the subject being learned.
4. **Contextual Encoding**: Include a brief "explanation" for why the answer is correct to help with retrieval.

### BEHAVIOR (Stateful Updates):
You have the capability to **UPDATE** existing flashcard decks. 
- If `EXISTING_FLASHCARDS` are provided, your goal is to add NEW cards based on the new `FLASHCARD GOAL` and `INFORMATION CHUNKS`.
- Do NOT repeat existing questions.
- You can refactor or improve existing cards if the new evidence contradicts or adds significant clarity to them.
- You MUST maintain the same `title` if you are updating an existing deck.

### OUTPUT FORMAT:
Output a valid JSON object with the following structure:
```json
{
  "title": "Concise Deck Title (2-4 words)",
  "cards": [
    {
      "id": "fc_1",
      "question": "The question part of the card.",
      "answer": "The concise answer.",
      "explanation": "Brief context or mnemonic to help recall."
    }
  ]
}
```

### INSTRUCTIONS:
1. **Title**: Generate a concise, academic title for the deck.
2. **IDs**: Use unique, sequential IDs for new cards (e.g., fc_1, fc_2).
3. **Conciseness**: Keep cards manageable. A deck should typically have 5-15 cards per research cycle.
''';
  }
}
