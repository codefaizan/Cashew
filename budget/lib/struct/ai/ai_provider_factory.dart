import 'package:budget/struct/ai/ai_provider.dart';
import 'package:budget/struct/ai/ai_provider_gemini_nano.dart';
import 'package:budget/struct/ai/ai_provider_gemma.dart';
import 'package:budget/struct/ai/ai_provider_openai.dart';
import 'package:budget/struct/settings.dart';

class AiProviderFactory {
  static const String geminiNanoKey = 'gemini_nano';
  static const String gemmaKey = 'gemma';
  static const String openAiKey = 'openai';

  static AiProvider createProvider({String? providerKey}) {
    final String key = providerKey ??
        (appStateSettings['aiLastUsedProvider'] as String?) ??
        geminiNanoKey;
    if (key == gemmaKey) return GemmaProvider();
    if (key == openAiKey) return OpenAiProvider();
    return GeminiNanoProvider();
  }

  static String keyForProvider(AiProvider provider) {
    if (provider is GemmaProvider) return gemmaKey;
    if (provider is OpenAiProvider) return openAiKey;
    return geminiNanoKey;
  }

  static List<AiProvider> createPriorityOrder({
    bool includeFallbackProviders = false,
    bool includeApiProviders = false,
  }) {
    final ordered = <AiProvider>[GeminiNanoProvider()];
    if (includeApiProviders) {
      ordered.add(OpenAiProvider());
    }
    if (includeFallbackProviders) {
      ordered.add(GemmaProvider());
    }
    return ordered;
  }
}
