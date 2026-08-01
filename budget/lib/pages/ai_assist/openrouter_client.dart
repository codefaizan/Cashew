import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:budget/pages/ai_assist/ai_assist_models.dart';

abstract class OpenRouterClient {
  Future<String> ocrImage(String imageBase64);

  Future<AiAssistResponse> sendMessage({
    required String userMessage,
    required List<ChatMessage> history,
    required List<String> categoryNames,
    required Map<String, String> walletNamesWithCurrencies,
    required String defaultWalletName,
    required String currentDate,
    TransactionDraft? currentDraft,
    String? ocrText,
  });
}

class HttpOpenRouterClient implements OpenRouterClient {
  static const _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const _ocrPrimaryModel = 'nvidia/nemotron-nano-12b-v2-vl:free';
  static const _ocrFallbackModel = 'google/gemma-4-31b-it:free';
  static const _primaryModel = 'openai/gpt-oss-20b:free';
  static const _fallbackModel = 'google/gemma-4-26b-a4b-it:free';

  final String apiKey;
  final http.Client _httpClient;

  HttpOpenRouterClient({
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<String> ocrImage(String imageBase64) async {
    try {
      return await _ocrWithModel(_ocrPrimaryModel, imageBase64);
    } catch (e) {
      if (e is OpenRouterAuthException) rethrow;
      try {
        return await _ocrWithModel(_ocrFallbackModel, imageBase64);
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<String> _ocrWithModel(String model, String imageBase64) async {
    final response = await _httpClient.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'Read all text from this image. Return only the extracted text, no commentary.',
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$imageBase64',
                },
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw OpenRouterAuthException('Invalid API key');
    }

    if (response.statusCode == 429) {
      throw OpenRouterRateLimitException('Rate limited');
    }

    if (response.statusCode != 200) {
      throw OpenRouterException(
          'OCR failed: ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>?;

    if (choices == null || choices.isEmpty) {
      throw OpenRouterException('Empty response from OCR model');
    }

    final content = choices[0]['message']['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw OpenRouterException('Empty content from OCR model');
    }

    return content.trim();
  }

  @override
  Future<AiAssistResponse> sendMessage({
    required String userMessage,
    required List<ChatMessage> history,
    required List<String> categoryNames,
    required Map<String, String> walletNamesWithCurrencies,
    required String defaultWalletName,
    required String currentDate,
    TransactionDraft? currentDraft,
    String? ocrText,
  }) async {
    final effectiveMessage = ocrText != null && ocrText.isNotEmpty
        ? 'Receipt contents:\n$ocrText\n\nUser message: $userMessage'
        : userMessage;

    try {
      return await _sendToModel(
        _primaryModel,
        effectiveMessage,
        history,
        categoryNames,
        walletNamesWithCurrencies,
        defaultWalletName,
        currentDate,
        currentDraft,
      );
    } catch (e) {
      if (e is OpenRouterAuthException) rethrow;
      try {
        return await _sendToModel(
          _fallbackModel,
          effectiveMessage,
          history,
          categoryNames,
          walletNamesWithCurrencies,
          defaultWalletName,
          currentDate,
          currentDraft,
        );
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<AiAssistResponse> _sendToModel(
    String model,
    String userMessage,
    List<ChatMessage> history,
    List<String> categoryNames,
    Map<String, String> walletNamesWithCurrencies,
    String defaultWalletName,
    String currentDate,
    TransactionDraft? currentDraft,
  ) async {
    final systemPrompt = _buildSystemPrompt(
      categoryNames,
      walletNamesWithCurrencies,
      defaultWalletName,
      currentDate,
      currentDraft,
    );

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => {
            'role': m.role,
            'content': m.content,
          }),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await _httpClient.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw OpenRouterAuthException('Invalid API key');
    }

    if (response.statusCode == 429) {
      throw OpenRouterRateLimitException('Rate limited');
    }

    if (response.statusCode != 200) {
      throw OpenRouterException(
          'OpenRouter returned ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>?;

    if (choices == null || choices.isEmpty) {
      throw OpenRouterException('Empty response from model');
    }

    final content = choices[0]['message']['content'] as String?;
    if (content == null || content.isEmpty) {
      throw OpenRouterException('Empty content in response');
    }

    try {
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      return AiAssistResponse.fromJson(parsed);
    } catch (_) {
      // Try to extract JSON from within text
      final jsonMatch =
          RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        final parsed =
            jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        return AiAssistResponse.fromJson(parsed);
      }
      rethrow;
    }
  }

  String _buildSystemPrompt(
    List<String> categoryNames,
    Map<String, String> walletNamesWithCurrencies,
    String defaultWalletName,
    String currentDate,
    TransactionDraft? currentDraft,
  ) {
    final catList = categoryNames.join(', ');
    final walletList = walletNamesWithCurrencies.entries
        .map((e) => '${e.key} (${e.value})')
        .join(', ');

    var prompt = '''You are a financial transaction parser for a budget app called Cashew.
Today's date is $currentDate.

Available categories: $catList
Available wallets: $walletList
Default wallet: $defaultWalletName

Parse the user's natural language into a transaction draft.
- Amount: positive number for expense, use income=true for income (amount is always positive)
- Date: YYYY-MM-DD format, default to $currentDate if not specified
- Wallet: match against available wallets, default to "$defaultWalletName"
- Category: match against available categories. If none fit, set createNewCategory=true with newCategoryName
- Title: a brief description of the transaction
- Note: any additional details the user provides
- If the user's input is unclear or missing critical info, provide a helpful assistantMessage asking for clarification

Respond with ONLY a JSON object:
{
  "assistantMessage": "short confirmation or question",
  "draft": {
    "income": false,
    "amount": 450.0,
    "title": "Coffee",
    "categoryName": "Food",
    "createNewCategory": false,
    "newCategoryName": null,
    "walletName": "$defaultWalletName",
    "date": "$currentDate",
    "note": null
  }
}
''';

    if (currentDraft != null) {
      prompt +=
          '\nCurrent draft to refine:\n${jsonEncode(currentDraft.toJson())}\n';
    }

    prompt +=
        '\nIf the user asks to change something, update the draft fields accordingly.';

    return prompt;
  }
}

class OpenRouterException implements Exception {
  final String message;
  const OpenRouterException(this.message);
  @override
  String toString() => message;
}

class OpenRouterAuthException extends OpenRouterException {
  const OpenRouterAuthException(super.message);
}

class OpenRouterRateLimitException extends OpenRouterException {
  const OpenRouterRateLimitException(super.message);
}
