import 'dart:io';
import 'package:budget/struct/ai/ai_provider_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const bool runGemmaAndroidTest =
      bool.fromEnvironment('RUN_GEMMA_ANDROID_TEST', defaultValue: false);

  testWidgets(
    'GemmaProvider initialize + generate returns non-empty response',
    (tester) async {
      await FlutterGemma.initialize();

      if (!Platform.isAndroid) {
        fail('This integration test must run on Android.');
      }

      final isCompatible = await GemmaProvider.isDeviceCompatible();
      expect(
        isCompatible,
        isTrue,
        reason: 'Device must satisfy API >= 24 and RAM >= 4GB.',
      );

      final provider = GemmaProvider();
      try {
        final modelDownloaded = await GemmaProvider.isModelDownloaded();
        if (!modelDownloaded) {
          await provider.downloadModel(onProgress: (_) {});
        }

        final initialized = await provider.initialize();
        expect(initialized, isTrue, reason: 'Model should initialize.');

        final response = await provider.generateChatResponse(
          systemPrompt: 'You are a concise assistant.',
          history: const [],
          userMessage: 'Hello',
        );

        expect(
          response.trim().isNotEmpty,
          isTrue,
          reason: 'Model must return non-empty text for simple prompt.',
        );
      } finally {
        await provider.dispose();
      }
    },
    skip: !runGemmaAndroidTest,
  );
}
