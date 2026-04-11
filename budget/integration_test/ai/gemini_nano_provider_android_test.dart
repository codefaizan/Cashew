import 'dart:io';

import 'package:budget/struct/ai/ai_provider_gemini_nano.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const bool runGeminiNanoAndroidTest = bool.fromEnvironment(
    'RUN_GEMINI_NANO_ANDROID_TEST',
    defaultValue: false,
  );

  testWidgets(
    'GeminiNanoProvider initialize + generate returns non-empty response',
    (tester) async {
      if (!Platform.isAndroid) {
        fail('This integration test must run on Android.');
      }

      final isCompatible = await GeminiNanoProvider.isDeviceCompatible();
      expect(
        isCompatible,
        isTrue,
        reason: 'Device must support Gemini Nano / AI Core for this test.',
      );

      final provider = GeminiNanoProvider();
      try {
        final initialized = await provider.initialize();
        expect(initialized, isTrue, reason: 'Gemini Nano should initialize.');

        final response = await provider.generateChatResponse(
          systemPrompt: 'You are a concise assistant.',
          history: const [],
          userMessage: 'Say hello in one short sentence.',
        );

        expect(
          response.trim().isNotEmpty,
          isTrue,
          reason: 'Gemini Nano must return non-empty text for simple prompt.',
        );
      } finally {
        await provider.dispose();
      }
    },
    skip: !runGeminiNanoAndroidTest,
  );
}
