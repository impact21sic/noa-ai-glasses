class Message {
  final String role; // 'user' or 'assistant'
  final String content;

  Message({
    required this.role,
    required this.content,
  });

  /// Convert to JSON format for API calls
  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }

  /// Create from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }

  /// Create a user message shortcut
  factory Message.user(String content) => Message(role: 'user', content: content);

  /// Create an assistant message shortcut
  factory Message.assistant(String content) => Message(role: 'assistant', content: content);
}
