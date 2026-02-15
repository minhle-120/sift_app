
class ResearchPackage {
  final List<int> indices;

  ResearchPackage({required this.indices});

  @override
  String toString() => 'ResearchPackage(indices: $indices)';
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
  final double? score;

  RAGResult({
    required this.content,
    required this.index,
    required this.sourceTitle,
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
  final Map<int, String> _idToContent = {};
  int _nextId = 1;

  int getIndex(String content) {
    // Basic normalization for hash stability
    final normalized = content.trim();
    if (_contentToId.containsKey(normalized)) {
      return _contentToId[normalized]!;
    }
    final id = _nextId++;
    _contentToId[normalized] = id;
    _idToContent[id] = normalized;
    return id;
  }

  String? getContent(int index) => _idToContent[index];

  void reset() {
    _contentToId.clear();
    _idToContent.clear();
    _nextId = 1;
  }
}
