import 'package:budget/struct/ai/ai_provider_openai.dart';
import 'package:budget/struct/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenAiProvider', () {
    setUp(() {
      appStateSettings = <String, dynamic>{};
    });

    test('initialize fails when API key is missing', () async {
      final provider = OpenAiProvider();
      final initialized = await provider.initialize();
      expect(initialized, isFalse);
      expect(provider.isAvailable, isFalse);
    });

    test('initialize succeeds when API key is present', () async {
      appStateSettings['aiOpenAiApiKey'] = 'test-key';
      final provider = OpenAiProvider();
      final initialized = await provider.initialize();
      expect(initialized, isTrue);
      expect(provider.isAvailable, isTrue);
    });

    test('initialize uses custom baseUrl and model when provided', () async {
      appStateSettings['aiOpenAiApiKey'] = 'test-key';
      appStateSettings['aiOpenAiBaseUrl'] = 'https://custom-api.example.com/v1';
      appStateSettings['aiOpenAiModel'] = 'gpt-4';

      final provider = OpenAiProvider();
      await provider.initialize();

      expect(provider.isAvailable, isTrue);
    });

    test('generateChatResponse throws when not initialized', () async {
      final provider = OpenAiProvider();
      expect(
        () => provider.generateChatResponse(
          systemPrompt: 'You are helpful.',
          history: const [],
          userMessage: 'Hello',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not initialized'),
        )),
      );
    });

    test('name returns OpenAI', () {
      final provider = OpenAiProvider();
      expect(provider.name, equals('OpenAI'));
    });

    test('initialize fails when API key is empty string', () async {
      appStateSettings['aiOpenAiApiKey'] = '';
      final provider = OpenAiProvider();
      final initialized = await provider.initialize();
      expect(initialized, isFalse);
      expect(provider.isAvailable, isFalse);
    });

    test('initialize trims whitespace from API key', () async {
      appStateSettings['aiOpenAiApiKey'] = '  test-key  ';
      appStateSettings['aiOpenAiBaseUrl'] = '  https://api.openai.com/v1  ';
      appStateSettings['aiOpenAiModel'] = '  gpt-3.5-turbo  ';

      final provider = OpenAiProvider();
      final initialized = await provider.initialize();
      expect(initialized, isTrue);
      expect(provider.isAvailable, isTrue);
    });

    test('dispose clears initialization state', () async {
      appStateSettings['aiOpenAiApiKey'] = 'test-key';
      final provider = OpenAiProvider();
      await provider.initialize();
      expect(provider.isAvailable, isTrue);

      await provider.dispose();
      expect(provider.isAvailable, isFalse);
    });
  });
}
