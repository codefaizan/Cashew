import 'package:budget/struct/ai/ai_provider.dart';
import 'package:budget/struct/ai/ai_provider_gemini_nano.dart';
import 'package:budget/struct/ai/ai_provider_gemma.dart';
import 'package:budget/struct/settings.dart';

class AiProviderFactory {
  static const String geminiNanoKey = 'gemini_nano';
  static const String gemmaKey = 'gemma';

  static AiProvider createProvider({String? providerKey}) {
    final String key = providerKey ??
        (appStateSettings['aiLastUsedProvider'] as String?) ??
        geminiNanoKey;
    if (key == gemmaKey) return GemmaProvider();
    return GeminiNanoProvider();
  }

  static String keyForProvider(AiProvider provider) {
    if (provider is GemmaProvider) return gemmaKey;
    return geminiNanoKey;
  }

  static List<AiProvider> createPriorityOrder({
    bool includeFallbackProviders = false,
  }) {
    final ordered = <AiProvider>[GeminiNanoProvider()];
    if (includeFallbackProviders) {
      ordered.add(GemmaProvider());
    }
    return ordered;
  }
}
