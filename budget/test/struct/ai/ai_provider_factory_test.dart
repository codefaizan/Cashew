import 'package:budget/struct/ai/ai_provider_factory.dart';
import 'package:budget/struct/ai/ai_provider_gemma.dart';
import 'package:budget/struct/ai/ai_provider_gemini_nano.dart';
import 'package:budget/struct/ai/ai_provider_openai.dart';
import 'package:budget/struct/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiProviderFactory', () {
    setUp(() {
      appStateSettings = <String, dynamic>{};
    });

    test('createProvider defaults to Gemini Nano when key is missing', () {
      final provider = AiProviderFactory.createProvider();
      expect(provider, isA<GeminiNanoProvider>());
    });

    test('createProvider returns Gemma when key is gemma', () {
      final provider = AiProviderFactory.createProvider(
          providerKey: AiProviderFactory.gemmaKey);
      expect(provider, isA<GemmaProvider>());
    });

    test('createProvider returns OpenAI when key is openai', () {
      final provider = AiProviderFactory.createProvider(
          providerKey: AiProviderFactory.openAiKey);
      expect(provider, isA<OpenAiProvider>());
    });

    test('createPriorityOrder returns Nano-only by default', () {
      final providers = AiProviderFactory.createPriorityOrder();
      expect(providers, hasLength(1));
      expect(providers.first, isA<GeminiNanoProvider>());
    });

    test('createPriorityOrder can include API providers', () {
      final providers =
          AiProviderFactory.createPriorityOrder(includeApiProviders: true);
      expect(providers, hasLength(2));
      expect(providers[0], isA<GeminiNanoProvider>());
      expect(providers[1], isA<OpenAiProvider>());
    });

    test('createPriorityOrder can include fallback providers', () {
      final providers =
          AiProviderFactory.createPriorityOrder(includeFallbackProviders: true);
      expect(providers, hasLength(2));
      expect(providers.first, isA<GeminiNanoProvider>());
      expect(providers.last, isA<GemmaProvider>());
    });

    test('createPriorityOrder can include both API and fallback providers', () {
      final providers = AiProviderFactory.createPriorityOrder(
        includeApiProviders: true,
        includeFallbackProviders: true,
      );
      expect(providers, hasLength(3));
      expect(providers[0], isA<GeminiNanoProvider>());
      expect(providers[1], isA<OpenAiProvider>());
      expect(providers[2], isA<GemmaProvider>());
    });

    test('keyForProvider maps provider instances to expected keys', () {
      expect(
        AiProviderFactory.keyForProvider(GeminiNanoProvider()),
        AiProviderFactory.geminiNanoKey,
      );
      expect(
        AiProviderFactory.keyForProvider(GemmaProvider()),
        AiProviderFactory.gemmaKey,
      );
      expect(
        AiProviderFactory.keyForProvider(OpenAiProvider()),
        AiProviderFactory.openAiKey,
      );
    });
  });
}
