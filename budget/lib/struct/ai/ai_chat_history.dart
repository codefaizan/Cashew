import 'dart:convert';
import 'package:budget/struct/ai/ai_provider.dart';
import 'package:budget/struct/settings.dart';

class AiChatHistory {
  static const int maxMessages = 10;

  List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void addMessage(ChatMessage message) {
    _messages.add(message);
    _persist();
  }

  void clear() {
    _messages.clear();
    _persist();
  }

  void truncateToLast(int n) {
    if (_messages.length > n) {
      _messages = _messages.sublist(_messages.length - n);
      _persist();
    }
  }

  void loadFromSettings() {
    final raw = appStateSettings["aiChatHistory"];
    if (raw is List && raw.isNotEmpty) {
      try {
        _messages = raw
            .map((item) => ChatMessage.fromJson(json.decode(item as String)))
            .toList();
      } catch (_) {
        _messages = [];
      }
    } else {
      _messages = [];
    }
  }

  void _persist() {
    appStateSettings["aiChatHistory"] =
        _messages.map((m) => json.encode(m.toJson())).toList();
  }
}
