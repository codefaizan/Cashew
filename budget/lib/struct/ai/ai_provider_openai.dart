import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:budget/struct/ai/ai_provider.dart';
import 'package:budget/struct/settings.dart';

class OpenAiProvider implements AiProvider {
  static const String _defaultBaseUrl = 'https://api.openai.com/v1';
  static const String _defaultModel = 'gpt-3.5-turbo';

  bool _initialized = false;
  String? _apiKey;
  String? _baseUrl;
  String? _model;
  String? _lastErrorCode;

  @override
  String get name => 'OpenAI';

  @override
  bool get isAvailable =>
      _initialized && _apiKey != null && _apiKey!.isNotEmpty;

  @override
  Future<bool> initialize() async {
    try {
      _lastErrorCode = null;
      _apiKey = (appStateSettings['aiOpenAiApiKey'] as String?)?.trim();
      _baseUrl = (appStateSettings['aiOpenAiBaseUrl'] as String?)?.trim() ??
          _defaultBaseUrl;
      _model = (appStateSettings['aiOpenAiModel'] as String?)?.trim() ??
          _defaultModel;

      if (_apiKey == null || _apiKey!.isEmpty) {
        _initialized = false;
        return false;
      }

      _initialized = true;
      return true;
    } catch (_) {
      _lastErrorCode = 'initialization-error';
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
          'OpenAiProvider not initialized. Call initialize() first.');
    }

    try {
      final messages = <Map<String, String>>[
        if (systemPrompt.isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        ...history.map((m) => {'role': m.role, 'content': m.content}),
        {'role': 'user', 'content': userMessage},
      ];

      print('=== OPENAI REQUEST === messages count: ${messages.length}');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'temperature': 0.7,
            }),
          )
          .timeout(
            const Duration(seconds: 90),
          );

      print('=== OPENAI RESPONSE === status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final choice = choices.first as Map<String, dynamic>;
          final message = choice['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
        throw StateError('OpenAI returned empty response.');
      } else if (response.statusCode == 401) {
        _lastErrorCode = 'unauthorized';
        throw StateError('OpenAI API key is invalid or expired.');
      } else if (response.statusCode == 429) {
        _lastErrorCode = 'rate-limit';
        print('=== OPENAI ERROR === Rate limited!');
        throw StateError('OpenAI rate limit exceeded. Please try again later.');
      } else {
        _lastErrorCode = 'api-error';
        final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
        final errorMessage = errorData?['error']?['message'] as String?;
        throw StateError(
          'OpenAI error (${response.statusCode}): ${errorMessage ?? response.reasonPhrase}',
        );
      }
    } catch (e) {
      if (e is StateError) rethrow;
      _lastErrorCode = 'network-error';
      throw StateError('OpenAI request failed: ${e.toString()}');
    }
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    _lastErrorCode = null;
  }

  String? get lastErrorCode => _lastErrorCode;
}
