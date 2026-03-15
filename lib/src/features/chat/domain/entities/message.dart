enum MessageRole {
  user,
  assistant,
  system,
  tool
}

class Message {
  final String id;
  final String text;
  final MessageRole role;
  final String? reasoning;
  final DateTime timestamp;
  final DateTime lastUpdatedAt;
  final Map<String, dynamic>? citations;
  final Map<String, dynamic>? metadata;

  Message({
    required this.id,
    required this.text,
    required this.role,
    this.reasoning,
    required this.timestamp,
    required this.lastUpdatedAt,
    this.citations,
    this.metadata,
  });

  bool get isEdited => metadata?['is_edited'] == true;
}
