import 'package:budget/struct/ai/ai_provider.dart';
import 'package:flutter/services.dart';

const MethodChannel _kGeminiNanoChannel =
    MethodChannel('cashew/ai_gemini_nano');

class GeminiNanoProvider implements AiProvider {
  bool _initialized = false;
  bool _available = false;
  String? _lastErrorCode;

  @override
  String get name => 'Gemini Nano';

  @override
  bool get isAvailable => _initialized && _available;

  static Future<bool> isDeviceCompatible() async {
    try {
      final bool? available =
          await _kGeminiNanoChannel.invokeMethod<bool>('isAvailable');
      return available == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> initialize() async {
    try {
      _lastErrorCode = null;
      _available = await isDeviceCompatible();
      if (!_available) {
        _initialized = false;
        return false;
      }

      final bool? initialized =
          await _kGeminiNanoChannel.invokeMethod<bool>('initialize');
      _initialized = initialized == true;
      return _initialized;
    } on PlatformException catch (e) {
      _lastErrorCode = e.code;
      _initialized = false;
      return false;
    } catch (_) {
      _lastErrorCode = 'unknown';
      _initialized = false;
      return false;
    }
  }

  @override
  Future<String> generateChatResponse({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    if (!isAvailable) {
      throw StateError(
          'GeminiNanoProvider not initialized. Call initialize() first.');
    }

    try {
      final String? response =
          await _kGeminiNanoChannel.invokeMethod<String>('generate', {
        'systemPrompt': systemPrompt,
        'history': history.map((message) => message.toJson()).toList(),
        'userMessage': userMessage,
      });
      if (response == null || response.trim().isEmpty) {
        throw StateError('Gemini Nano returned empty response.');
      }
      return response;
    } on PlatformException catch (e) {
      _lastErrorCode = e.code;
      final mappedMessage = switch (e.code) {
        'unavailable' => 'Gemini Nano is unavailable on this device.',
        'timeout' => 'Gemini Nano request timed out. Please try again.',
        'empty-response' => 'Gemini Nano returned an empty response.',
        _ =>
          'Gemini Nano generation failed: ${e.code} ${e.message ?? ''}'.trim(),
      };
      throw StateError(
        mappedMessage,
      );
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _kGeminiNanoChannel.invokeMethod<void>('dispose');
    } catch (_) {}
    _initialized = false;
    _lastErrorCode = null;
  }

  String? get lastErrorCode => _lastErrorCode;
}
