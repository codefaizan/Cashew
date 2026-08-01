import 'dart:convert';
import 'package:budget/pages/ai_assist/ai_assist_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiAssistSession {
  static const _storageKey = 'aiAssistChatSession';

  final List<ChatMessage> messages;
  final TransactionDraft? currentDraft;

  const AiAssistSession({
    this.messages = const [],
    this.currentDraft,
  });

  AiAssistSession copyWith({
    List<ChatMessage>? messages,
    TransactionDraft? currentDraft,
  }) {
    return AiAssistSession(
      messages: messages ?? this.messages,
      currentDraft: currentDraft ?? this.currentDraft,
    );
  }

  Map<String, dynamic> toJson() => {
        'messages': messages.map((m) => m.toJson()).toList(),
        'currentDraft': currentDraft?.toJson(),
      };

  factory AiAssistSession.fromJson(Map<String, dynamic> json) {
    return AiAssistSession(
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) =>
                  ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      currentDraft: json['currentDraft'] != null
          ? TransactionDraft.fromJson(
              json['currentDraft'] as Map<String, dynamic>)
          : null,
    );
  }

  static Future<AiAssistSession> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const AiAssistSession();
    }
    try {
      return AiAssistSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AiAssistSession();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  String get lastUserMessage {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'user') return messages[i].content;
    }
    return '';
  }
}
