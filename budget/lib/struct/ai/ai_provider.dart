abstract class AiProvider {
  String get name;
  bool get isAvailable;
  Future<bool> initialize();
  Future<String> generateChatResponse({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  });
  Future<void> dispose();
}

class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      ChatMessage(role: json['role'], content: json['content']);
}
