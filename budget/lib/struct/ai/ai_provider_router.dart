import 'package:budget/struct/ai/ai_provider.dart';
import 'package:budget/struct/ai/ai_provider_factory.dart';
import 'package:budget/struct/settings.dart';

class AiProviderSelection {
  final AiProvider provider;
  final String providerKey;

  const AiProviderSelection({
    required this.provider,
    required this.providerKey,
  });
}

class AiProviderRouter {
  static Future<AiProviderSelection?> selectFirstReadyProvider({
    bool includeFallbackProviders = false,
  }) async {
    final providers = AiProviderFactory.createPriorityOrder(
      includeFallbackProviders: includeFallbackProviders,
    );

    for (final provider in providers) {
      final initialized = await provider.initialize();
      if (!initialized || !provider.isAvailable) {
        await provider.dispose();
        continue;
      }

      final key = AiProviderFactory.keyForProvider(provider);
      appStateSettings['aiLastUsedProvider'] = key;
      return AiProviderSelection(provider: provider, providerKey: key);
    }

    return null;
  }
}
