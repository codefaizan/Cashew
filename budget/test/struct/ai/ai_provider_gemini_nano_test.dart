import 'package:budget/struct/ai/ai_provider.dart';
import 'package:budget/struct/ai/ai_provider_gemini_nano.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('cashew/ai_gemini_nano');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize returns true when native reports available + initialized',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'isAvailable') return true;
      if (call.method == 'initialize') return true;
      return null;
    });

    final provider = GeminiNanoProvider();
    final initialized = await provider.initialize();

    expect(initialized, isTrue);
    expect(provider.isAvailable, isTrue);
  });

  test('initialize returns false when native reports unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'isAvailable') return false;
      fail('initialize should not be called when unavailable');
    });

    final provider = GeminiNanoProvider();
    final initialized = await provider.initialize();

    expect(initialized, isFalse);
    expect(provider.isAvailable, isFalse);
  });

  test('generateChatResponse maps timeout error to user-safe message',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'isAvailable') return true;
      if (call.method == 'initialize') return true;
      if (call.method == 'generate') {
        throw PlatformException(code: 'timeout', message: 'native timeout');
      }
      return null;
    });

    final provider = GeminiNanoProvider();
    await provider.initialize();

    expect(
      () => provider.generateChatResponse(
        systemPrompt: 'You are concise.',
        history: const <ChatMessage>[],
        userMessage: 'Hello',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });
}
