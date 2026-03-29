import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/services/openai_service.dart';

class QuizPackage {
  final List<int> indices;
  final String topicGoal;

  QuizPackage({required this.indices, required this.topicGoal});

  @override
  String toString() => 'QuizPackage(indices: $indices, goal: $topicGoal)';
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correctIndex'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };
}

class QuizResult {
  final QuizPackage package;
  final String title;
  final List<QuizQuestion> questions;
  final List<ChatMessage> steps;

  QuizResult({
    required this.package,
    required this.title,
    required this.questions,
    required this.steps,
  });
}

class QuizOrchestrator {
  final Ref _ref;

  QuizOrchestrator(this._ref);

  Future<QuizResult> generateQuiz({
    required QuizPackage package,
    required ChunkRegistry registry,
    required String fullContext,
  }) async {
    final aiService = _ref.read(aiServiceProvider);

    // 1. Compile selected chunks
    final StringBuffer contextBuffer = StringBuffer();
    for (final index in package.indices) {
      final chunk = registry.getResult(index);
      if (chunk != null) {
        contextBuffer.writeln(chunk.toString());
      }
    }
    final sourceContext = contextBuffer.toString();

    // 2. Build system and user prompts
    final String baseSystemPrompt = '''
You are an expert Quiz Generator.
Your task is to generate exactly 4 multiple-choice questions based ONLY on the provided source material.
The user goal is: ${package.topicGoal}

For each question:
1. Provide a clear, concise question.
2. Provide exactly 4 options.
3. Indicate the zero-based index of the correct option (0, 1, 2, or 3).
4. Provide a brief explanation of why the answer is correct or why the others are wrong.

You MUST respond ONLY with a JSON object in this exact format, with no markdown formatting or other text:
{
  "title": "A short, descriptive title for the quiz",
  "questions": [
    {
      "question": "The question text here?",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctIndex": 0,
      "explanation": "Explanation here..."
    }
  ]
}
''';

    final String userPrompt = '''
SOURCE MATERIAL:
${sourceContext.isEmpty ? "Context:\n$fullContext" : sourceContext}

Generate the 4-question quiz now.
''';

    // 3. Delegate to LLM
    final steps = <ChatMessage>[];
    
    steps.add(ChatMessage(
      role: ChatRole.system,
      content: baseSystemPrompt,
    ));
    steps.add(ChatMessage(
      role: ChatRole.user,
      content: userPrompt,
    ));

    try {
      final response = await aiService.chat(steps);
      final jsonResponse = _extractJson(response.content);

      final assistantMessage = ChatMessage(
        role: ChatRole.assistant,
        content: jsonResponse,
      );
      steps.add(assistantMessage);

      // 4. Parse result
      final Map<String, dynamic> responseMap = jsonDecode(jsonResponse);
      final String title = responseMap['title'] as String? ?? 'Generated Quiz';
      final List<dynamic> questionsRaw = responseMap['questions'] as List<dynamic>? ?? [];
      
      final List<QuizQuestion> questions = questionsRaw.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>)).toList();

      return QuizResult(
        package: package,
        title: title,
        questions: questions.take(4).toList(), // Ensure exactly 4
        steps: steps,
      );
    } catch (e) {
      // Fallback in case of failure
      return QuizResult(
        package: package,
        title: 'Error Generating Quiz',
        questions: [],
        steps: steps,
      );
    }
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
}

final quizOrchestratorProvider = Provider<QuizOrchestrator>((ref) {
  return QuizOrchestrator(ref);
});
