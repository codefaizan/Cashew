import 'dart:convert';
import 'package:budget/struct/ai/ai_chat_history.dart';
import 'package:budget/struct/ai/ai_provider.dart';
import 'package:budget/struct/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiChatHistory', () {
    late AiChatHistory history;

    setUp(() {
      history = AiChatHistory();
      appStateSettings["aiChatHistory"] = <dynamic>[];
    });

    test('starts empty', () {
      expect(history.messages, isEmpty);
    });

    test('addMessage adds a message', () {
      history.addMessage(ChatMessage(role: 'user', content: 'hello'));
      expect(history.messages.length, 1);
      expect(history.messages[0].role, 'user');
      expect(history.messages[0].content, 'hello');
    });

    test('clear removes all messages', () {
      history.addMessage(ChatMessage(role: 'user', content: 'hello'));
      history.addMessage(ChatMessage(role: 'assistant', content: 'hi'));
      history.clear();
      expect(history.messages, isEmpty);
    });

    test('truncateToLast keeps only last N messages', () {
      for (int i = 0; i < 15; i++) {
        history.addMessage(ChatMessage(role: 'user', content: 'msg $i'));
      }
      history.truncateToLast(10);
      expect(history.messages.length, 10);
      expect(history.messages.first.content, 'msg 5');
      expect(history.messages.last.content, 'msg 14');
    });

    test('truncateToLast does nothing when under limit', () {
      for (int i = 0; i < 5; i++) {
        history.addMessage(ChatMessage(role: 'user', content: 'msg $i'));
      }
      history.truncateToLast(10);
      expect(history.messages.length, 5);
    });

    test('addMessage triggers truncation to maxMessages', () {
      for (int i = 0; i < 15; i++) {
        history.addMessage(ChatMessage(role: 'user', content: 'msg $i'));
      }
      history.truncateToLast(AiChatHistory.maxMessages);
      expect(history.messages.length, AiChatHistory.maxMessages);
    });

    test('messages list is unmodifiable', () {
      history.addMessage(ChatMessage(role: 'user', content: 'hello'));
      expect(
          () => history.messages.add(ChatMessage(role: 'user', content: 'x')),
          throwsUnsupportedError);
    });

    test('loadFromSettings parses persisted messages', () {
      appStateSettings["aiChatHistory"] = [
        json.encode({'role': 'user', 'content': 'hi'}),
        json.encode({'role': 'assistant', 'content': 'hello'}),
      ];
      final h = AiChatHistory();
      h.loadFromSettings();
      expect(h.messages.length, 2);
      expect(h.messages[0].content, 'hi');
      expect(h.messages[1].content, 'hello');
    });

    test('loadFromSettings handles empty settings gracefully', () {
      appStateSettings["aiChatHistory"] = <dynamic>[];
      final h = AiChatHistory();
      h.loadFromSettings();
      expect(h.messages, isEmpty);
    });

    test('loadFromSettings handles invalid JSON gracefully', () {
      appStateSettings["aiChatHistory"] = ['not valid json'];
      final h = AiChatHistory();
      h.loadFromSettings();
      expect(h.messages, isEmpty);
    });
  });

  group('ChatMessage', () {
    test('toJson and fromJson round-trip', () {
      final msg = ChatMessage(role: 'user', content: 'hello');
      final json = msg.toJson();
      final restored = ChatMessage.fromJson(json);
      expect(restored.role, 'user');
      expect(restored.content, 'hello');
    });
  });
}
