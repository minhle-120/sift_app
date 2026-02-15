
class ResearchPackage {
  final List<int> indices;

  ResearchPackage({required this.indices});

  @override
  String toString() => 'ResearchPackage(indices: $indices)';
}

class ResearchResult {
  final ChatMessage? output;
  final ResearchPackage? package;
  final List<ChatMessage>? steps;
  final bool noInfoFound;
  final String? noInfoReason;

  ResearchResult({
    this.output,
    this.package,
    this.steps,
    this.noInfoFound = false,
    this.noInfoReason,
  });
}

enum ChatRole {
  system,
  user,
  assistant,
  tool,
}

class ChatMessage {
  final ChatRole role;
  final String content;
  final String? name; // For tool role
  final String? toolCallId; // For tool response
  final List<ToolCall>? toolCalls;

  ChatMessage({
    required this.role,
    required this.content,
    this.name,
    this.toolCallId,
    this.toolCalls,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
      if (name != null) 'name': name,
      if (toolCallId != null) 'tool_call_id': toolCallId,
      if (toolCalls != null) 'tool_calls': toolCalls!.map((e) => e.toJson()).toList(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: ChatRole.values.firstWhere((e) => e.name == json['role']),
      content: json['content'] ?? '',
      name: json['name'],
      toolCallId: json['tool_call_id'],
      toolCalls: json['tool_calls'] != null
          ? (json['tool_calls'] as List).map((e) => ToolCall.fromJson(e)).toList()
          : null,
    );
  }
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
    return '[[Chunk $index]] Source: $sourceTitle\n$content';
  }
}

/// Helper to maintain stable indexing for chunks in a single research session.
class ChunkRegistry {
  final Map<String, int> _contentToId = {};
  final Map<int, RAGResult> _idToResult = {};
  int _nextId = 1;

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
