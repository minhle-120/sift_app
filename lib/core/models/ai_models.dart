
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GraphGeneratorMode { auto, off, on }
enum CoderMode { auto, off, on }
enum FlashcardMode { auto, off, on }
enum InteractiveCanvasMode { auto, off, on }

enum AiConnectionStatus { ok, loading, unreachable }

class ResearchPackage {
  final List<int> indices;

  ResearchPackage({required this.indices});

  @override
  String toString() => 'ResearchPackage(indices: $indices)';
}
class ResearchResult {
  final ChatMessage? output;
  final ResearchPackage? package;
  final GraphPackage? graphPackage;
  final String? graphSchema;
  final GraphGeneratorMode? graphGeneratorMode;
  final CodePackage? codePackage;
  final String? codeSnippet;
  final String? codeLanguage;
  final String? codeTitle;
  final FlashcardPackage? flashcardPackage;
  final List<Flashcard>? flashcardResult;
  final String? flashcardTitle;
  final FlashcardMode? flashcardMode;
  final InteractiveCanvasPackage? canvasPackage;
  final String? canvasHtml;
  final InteractiveCanvasMode? interactiveCanvasMode;
  final List<ChatMessage>? steps;
  final bool noInfoFound;
  final String? noInfoReason;
  final bool canceled;

  ResearchResult({
    this.output,
    this.package,
    this.graphPackage,
    this.graphSchema,
    this.codePackage,
    this.codeSnippet,
    this.codeLanguage,
    this.codeTitle,
    this.flashcardPackage,
    this.flashcardResult,
    this.flashcardTitle,
    this.flashcardMode,
    this.graphGeneratorMode,
    this.canvasPackage,
    this.canvasHtml,
    this.interactiveCanvasMode,
    this.steps,
    this.noInfoFound = false,
    this.noInfoReason,
    this.canceled = false,
  });
}

class GraphPackage {
  final List<int> indices;
  final String graphGoal;

  GraphPackage({required this.indices, required this.graphGoal});

  @override
  String toString() => 'GraphPackage(indices: $indices, goal: $graphGoal)';
}

class CodePackage {
  final List<int> indices;
  final String codingGoal;

  CodePackage({required this.indices, required this.codingGoal});

  @override
  String toString() => 'CodePackage(indices: $indices, goal: $codingGoal)';
}

class FlashcardPackage {
  final List<int> indices;
  final String studyGoal;

  FlashcardPackage({required this.indices, required this.studyGoal});

  @override
  String toString() => 'FlashcardPackage(indices: $indices, goal: $studyGoal)';
}

class InteractiveCanvasPackage {
  final List<int> indices;
  final String canvasGoal;

  InteractiveCanvasPackage({required this.indices, required this.canvasGoal});

  @override
  String toString() => 'InteractiveCanvasPackage(indices: $indices, goal: $canvasGoal)';
}

class GraphResult {
  final GraphPackage package;
  final String schema;
  final List<ChatMessage> steps;

  GraphResult({required this.package, required this.schema, required this.steps});
}

class CodeResult {
  final CodePackage package;
  final String codeSnippet;
  final String language;
  final String? title;
  final List<ChatMessage> steps;

  CodeResult({
    required this.package,
    required this.codeSnippet,
    this.language = 'plaintext',
    this.title,
    required this.steps,
  });
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

class InteractiveCanvasResult {
  final InteractiveCanvasPackage package;
  final String htmlContent;
  final List<ChatMessage> steps;

  InteractiveCanvasResult({
    required this.package,
    required this.htmlContent,
    required this.steps,
  });
}

enum ChatRole {
  system,
  user,
  assistant,
  tool,
}

abstract class ContentPart {
  Map<String, dynamic> toJson();
  
  static ContentPart fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type == 'text') return TextPart(json['text'] ?? '');
    if (type == 'image_url') {
      final url = json['image_url']?['url'] ?? '';
      return ImagePart(url);
    }
    return TextPart(''); // Fallback
  }
}

class TextPart extends ContentPart {
  final String text;
  TextPart(this.text);
  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'text': text};
}

class ImagePart extends ContentPart {
  final String base64Data;
  final String mimeType;
  ImagePart(this.base64Data, {this.mimeType = 'image/jpeg'});
  
  @override
  Map<String, dynamic> toJson() => {
    'type': 'image_url',
    'image_url': {
      'url': 'data:$mimeType;base64,$base64Data',
    }
  };
}

class ChatMessage {
  final ChatRole role;
  
  /// content can be a String or a List<ContentPart> for multi-modal messages.
  final dynamic content;
  
  final String? reasoning;
  final String? name; // For tool role
  final String? toolCallId; // For tool response
  final List<ToolCall>? toolCalls;

  ChatMessage({
    required this.role,
    required this.content,
    this.reasoning,
    this.name,
    this.toolCallId,
    this.toolCalls,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content is List<ContentPart> 
          ? (content as List<ContentPart>).map((p) => p.toJson()).toList()
          : content,
      if (reasoning != null) 'reasoning_content': reasoning,
      if (name != null) 'name': name,
      if (toolCallId != null) 'tool_call_id': toolCallId,
      if (toolCalls != null) 'tool_calls': toolCalls!.map((e) => e.toJson()).toList(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final jsonContent = json['content'];
    dynamic parsedContent;
    if (jsonContent is List) {
      parsedContent = jsonContent.map((p) => ContentPart.fromJson(p as Map<String, dynamic>)).toList();
    } else {
      parsedContent = jsonContent ?? '';
    }

    return ChatMessage(
      role: ChatRole.values.firstWhere((e) => e.name == json['role']),
      content: parsedContent,
      reasoning: json['reasoning_content'],
      name: json['name'],
      toolCallId: json['tool_call_id'],
      toolCalls: json['tool_calls'] != null
          ? (json['tool_calls'] as List).map((e) => ToolCall.fromJson(e)).toList()
          : null,
    );
  }
}

class ChatStreamChunk {
  final String? content;
  final String? reasoningContent;

  ChatStreamChunk({this.content, this.reasoningContent});
}

class ToolCall {
  final String id;
  final String type;
  final FunctionCall function;

  ToolCall({
    required this.id,
    this.type = 'function',
    required this.function,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'function': function.toJson(),
    };
  }

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      id: json['id'],
      type: json['type'] ?? 'function',
      function: FunctionCall.fromJson(json['function']),
    );
  }
}

class FunctionCall {
  final String name;
  final String arguments; // JSON string

  FunctionCall({
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'arguments': arguments,
      };

  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(
      name: json['name'],
      arguments: json['arguments'],
    );
  }
}

class ToolDefinition {
  final String type;
  final FunctionDefinition function;

  ToolDefinition({
    this.type = 'function',
    required this.function,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'function': function.toJson(),
      };
}

class FunctionDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  FunctionDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'parameters': parameters,
      };
}

/// Represents a chunk of knowledge with a stable session index.
class RAGResult {
  final String content;
  final int index;
  final String sourceTitle;
  final int documentId;
  final int chunkIndex;
  final double? score;

  RAGResult({
    required this.content,
    required this.index,
    required this.sourceTitle,
    required this.documentId,
    required this.chunkIndex,
    this.score,
  });

  @override
  String toString() {
    return '[[Chunk $index]]\n$content';
  }
}

/// Helper to maintain stable indexing for chunks in a single research session.
class ChunkRegistry {
  final Ref ref;
  final Map<String, int> _contentToId = {};
  final Map<int, RAGResult> _idToResult = {};
  int _nextId = 1;

  ChunkRegistry(this.ref);

  int register(String content, String sourceTitle, int documentId, int chunkIndex, [double? score]) {
    final normalized = content.trim();
    if (_contentToId.containsKey(normalized)) {
      return _contentToId[normalized]!;
    }
    final id = _nextId++;
    _contentToId[normalized] = id;
    _idToResult[id] = RAGResult(
      content: content,
      index: id,
      sourceTitle: sourceTitle,
      documentId: documentId,
      chunkIndex: chunkIndex,
      score: score,
    );
    return id;
  }

  RAGResult? getResult(int index) => _idToResult[index];

  List<RAGResult> getAllResults() => _idToResult.values.toList();

  void reset() {
    _contentToId.clear();
    _idToResult.clear();
    _nextId = 1;
  }
}
