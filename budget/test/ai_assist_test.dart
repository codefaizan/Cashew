import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:budget/pages/ai_assist/ai_assist_models.dart';
import 'package:budget/pages/ai_assist/ai_assist_session.dart';
import 'package:budget/pages/ai_assist/openrouter_client.dart';

void main() {
  group('TransactionDraft', () {
    test('serializes to JSON correctly', () {
      final draft = TransactionDraft(
        income: false,
        amount: 450.0,
        title: 'Coffee',
        categoryName: 'Food',
        walletName: 'Cash',
        date: '2026-07-31',
      );

      final json = draft.toJson();
      expect(json['income'], false);
      expect(json['amount'], 450.0);
      expect(json['title'], 'Coffee');
      expect(json['categoryName'], 'Food');
      expect(json['createNewCategory'], false);
      expect(json['newCategoryName'], null);
      expect(json['walletName'], 'Cash');
      expect(json['date'], '2026-07-31');
    });

    test('deserializes from JSON', () {
      final json = {
        'income': true,
        'amount': 80000.0,
        'title': 'Salary',
        'categoryName': 'Income',
        'createNewCategory': true,
        'newCategoryName': 'Freelance',
        'walletName': 'Bank',
        'date': '2026-07-31',
        'note': 'Monthly salary',
      };

      final draft = TransactionDraft.fromJson(json);
      expect(draft.income, true);
      expect(draft.amount, 80000.0);
      expect(draft.title, 'Salary');
      expect(draft.categoryName, 'Income');
      expect(draft.createNewCategory, true);
      expect(draft.newCategoryName, 'Freelance');
      expect(draft.walletName, 'Bank');
      expect(draft.date, '2026-07-31');
      expect(draft.note, 'Monthly salary');
    });

    test('copyWith updates fields', () {
      final original = TransactionDraft(
        income: false,
        amount: 100.0,
        title: 'Original',
      );

      final updated = original.copyWith(
        amount: 200.0,
        title: 'Updated',
        income: true,
      );

      expect(updated.amount, 200.0);
      expect(updated.title, 'Updated');
      expect(updated.income, true);
      expect(updated.categoryName, null);
    });

    test('isValid checks required fields', () {
      expect(TransactionDraft().isValid, false);
      expect(TransactionDraft(amount: 100.0, title: '').isValid, false);
      expect(TransactionDraft(amount: 100.0, title: 'Test').isValid, true);
      expect(TransactionDraft(amount: 0.0, title: 'Test').isValid, false);
    });
  });

  group('ChatMessage', () {
    test('serializes to JSON', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Here is your draft',
        draft: TransactionDraft(amount: 50.0, title: 'Lunch'),
        draftStatus: DraftStatus.pending,
      );

      final json = msg.toJson();
      expect(json['role'], 'assistant');
      expect(json['content'], 'Here is your draft');
      expect(json['draft'], isNotNull);
      expect(json['draftStatus'], 'pending');
    });

    test('deserializes from JSON', () {
      final json = {
        'role': 'user',
        'content': 'coffee 450',
        'draft': null,
        'draftStatus': null,
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.role, 'user');
      expect(msg.content, 'coffee 450');
      expect(msg.draft, null);
      expect(msg.draftStatus, null);
    });

    test('with image round-trip preserves imageBase64', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'groceries',
        imageBase64: 'aGVsbG8=',
      );

      final json = msg.toJson();
      expect(json['imageBase64'], 'aGVsbG8=');
      expect(json['isOcrMessage'], false);

      final restored = ChatMessage.fromJson(json);
      expect(restored.imageBase64, 'aGVsbG8=');
      expect(restored.hasImage, true);
      expect(restored.isOcrMessage, false);
    });

    test('without image hasImage is false', () {
      final msg = ChatMessage(role: 'user', content: 'hello');
      expect(msg.hasImage, false);
      expect(msg.imageBase64, null);

      final json = msg.toJson();
      expect(json['imageBase64'], null);

      final restored = ChatMessage.fromJson(json);
      expect(restored.hasImage, false);
      expect(restored.imageBase64, null);
    });

    test('with empty imageBase64 hasImage returns false', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'hello',
        imageBase64: '',
      );
      expect(msg.hasImage, false);
    });

    test('with isOcrMessage serialization', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Walmart Supercenter\nMilk \$3.49\nTotal \$5.78',
        isOcrMessage: true,
      );

      final json = msg.toJson();
      expect(json['isOcrMessage'], true);
      expect(json['role'], 'assistant');
      expect(json['content'], 'Walmart Supercenter\nMilk \$3.49\nTotal \$5.78');

      final restored = ChatMessage.fromJson(json);
      expect(restored.isOcrMessage, true);
      expect(restored.role, 'assistant');
      expect(restored.draft, null);
    });

    test('fromJson with missing isOcrMessage defaults to false', () {
      final json = {
        'role': 'assistant',
        'content': 'hi',
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.isOcrMessage, false);
    });
  });

  group('AiAssistResponse', () {
    test('parses full response with draft', () {
      final json = {
        'assistantMessage': 'Got it! Here is your expense draft.',
        'draft': {
          'income': false,
          'amount': 450.0,
          'title': 'Coffee',
          'categoryName': 'Food',
          'createNewCategory': false,
          'newCategoryName': null,
          'walletName': 'Cash',
          'date': '2026-07-31',
          'note': null,
        },
      };

      final response = AiAssistResponse.fromJson(json);
      expect(response.assistantMessage, 'Got it! Here is your expense draft.');
      expect(response.draft, isNotNull);
      expect(response.draft!.amount, 450.0);
      expect(response.draft!.title, 'Coffee');
    });

    test('parses response with no draft', () {
      final json = {
        'assistantMessage': 'Could you specify an amount?',
        'draft': <String, dynamic>{},
      };

      final response = AiAssistResponse.fromJson(json);
      expect(response.assistantMessage, 'Could you specify an amount?');
      expect(response.draft, null);
    });

    test('parses response with missing draft field', () {
      final json = {
        'assistantMessage': 'What category?',
      };

      final response = AiAssistResponse.fromJson(json);
      expect(response.assistantMessage, 'What category?');
      expect(response.draft, null);
    });
  });

  group('AiAssistSession', () {
    test('serializes to JSON', () {
      final session = AiAssistSession(
        messages: [
          ChatMessage(role: 'user', content: 'coffee 450'),
          ChatMessage(
            role: 'assistant',
            content: 'Draft ready',
            draft: TransactionDraft(amount: 450.0, title: 'Coffee'),
            draftStatus: DraftStatus.pending,
          ),
        ],
        currentDraft: TransactionDraft(amount: 450.0, title: 'Coffee'),
      );

      final json = session.toJson();
      expect(json['messages'], isA<List>());
      expect((json['messages'] as List).length, 2);
      expect(json['currentDraft'], isNotNull);
    });

    test('deserializes from JSON', () {
      final json = {
        'messages': [
          {'role': 'user', 'content': 'hello', 'draft': null, 'draftStatus': null},
          {
            'role': 'assistant',
            'content': 'hi',
            'draft': {'income': false, 'amount': 100.0, 'title': 'Test'},
            'draftStatus': 'pending',
          },
        ],
        'currentDraft': {'income': false, 'amount': 100.0, 'title': 'Test'},
      };

      final session = AiAssistSession.fromJson(json);
      expect(session.messages.length, 2);
      expect(session.messages[0].role, 'user');
      expect(session.messages[0].content, 'hello');
      expect(session.messages[1].role, 'assistant');
      expect(session.messages[1].draft, isNotNull);
      expect(session.messages[1].draftStatus, DraftStatus.pending);
      expect(session.currentDraft, isNotNull);
      expect(session.currentDraft!.amount, 100.0);
    });

    test('deserializes empty/partial JSON gracefully', () {
      final session = AiAssistSession.fromJson({});
      expect(session.messages, isEmpty);
      expect(session.currentDraft, null);
    });

    test('copyWith works', () {
      final original = AiAssistSession(messages: [
        ChatMessage(role: 'user', content: 'hello'),
      ]);

      final updated = original.copyWith(
        messages: [
          ...original.messages,
          ChatMessage(role: 'assistant', content: 'hi'),
        ],
      );

      expect(updated.messages.length, 2);
      expect(original.messages.length, 1);
    });

    test('session round-trips with imageBase64 in messages', () {
      final session = AiAssistSession(
        messages: [
          ChatMessage(
            role: 'user',
            content: 'groceries',
            imageBase64: 'dGVzdA==',
          ),
          ChatMessage(
            role: 'assistant',
            content: 'Walmart receipt text',
            isOcrMessage: true,
          ),
          ChatMessage(
            role: 'assistant',
            content: 'Got it',
            draft: TransactionDraft(amount: 100.0, title: 'Test'),
            draftStatus: DraftStatus.pending,
          ),
        ],
      );

      final json = session.toJson();
      final restored = AiAssistSession.fromJson(json);

      expect(restored.messages.length, 3);
      expect(restored.messages[0].imageBase64, 'dGVzdA==');
      expect(restored.messages[0].hasImage, true);
      expect(restored.messages[1].isOcrMessage, true);
      expect(restored.messages[2].draft, isNotNull);
    });
  });

  group('HttpOpenRouterClient OCR', () {
    test('returns raw text from primary OCR model', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final model = body['model'] as String;
        expect(model, 'nvidia/nemotron-nano-12b-v2-vl:free');

        // Verify the request uses vision format (content array)
        final messages = body['messages'] as List<dynamic>;
        final userContent = messages[0]['content'];
        expect(userContent, isA<List>());
        final contentParts = userContent as List<dynamic>;
        expect(contentParts.length, 2);
        expect(contentParts[0]['type'], 'text');
        expect(contentParts[1]['type'], 'image_url');
        expect(
          contentParts[1]['image_url']['url'],
          'data:image/jpeg;base64,dGVzdGltYWdl',
        );

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': 'Walmart\nMilk \$3.49\nTotal \$5.78',
                },
              },
            ],
          }),
          200,
        );
      });

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final result = await client.ocrImage('dGVzdGltYWdl');
      expect(result, 'Walmart\nMilk \$3.49\nTotal \$5.78');
    });

    test('falls back to secondary OCR model on primary failure', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final model = body['model'] as String;

        if (model == 'nvidia/nemotron-nano-12b-v2-vl:free') {
          return http.Response('Server error', 500);
        }
        // Fallback model
        expect(model, 'google/gemma-4-31b-it:free');

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Fallback OCR text'},
              },
            ],
          }),
          200,
        );
      });

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final result = await client.ocrImage('dGVzdGltYWdl');
      expect(callCount, 2);
      expect(result, 'Fallback OCR text');
    });

    test('throws when both OCR models fail', () async {
      final mockClient = MockClient((_) async => http.Response('Service down', 503));

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      expect(
        () => client.ocrImage('dGVzdGltYWdl'),
        throwsA(isA<OpenRouterException>()),
      );
    });

    test('auth error on OCR skips fallback', () async {
      bool fallbackCalled = false;
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final model = body['model'] as String;
        if (model == 'google/gemma-4-31b-it:free') {
          fallbackCalled = true;
        }
        return http.Response('Unauthorized', 401);
      });

      final client = HttpOpenRouterClient(
        apiKey: 'bad-key',
        httpClient: mockClient,
      );

      try {
        await client.ocrImage('dGVzdGltYWdl');
        fail('Expected OpenRouterAuthException');
      } on OpenRouterAuthException {
        // Expected
      }
      // Auth error should skip fallback — fallback must not have been called
      expect(fallbackCalled, false);
    });

    test('throws on empty OCR response content', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '   '},
              },
            ],
          }),
          200,
        );
      });

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      expect(
        () => client.ocrImage('dGVzdGltYWdl'),
        throwsA(isA<OpenRouterException>()),
      );
    });

    test('throws on empty OCR choices', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({'choices': <dynamic>[]}),
          200,
        );
      });

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      expect(
        () => client.ocrImage('dGVzdGltYWdl'),
        throwsA(isA<OpenRouterException>()),
      );
    });
  });

  group('HttpOpenRouterClient sendMessage', () {
    test('returns parsed response on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-key');
        expect(request.headers['Content-Type'], 'application/json');

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'assistantMessage': 'Here is your expense',
                    'draft': {
                      'income': false,
                      'amount': 450.0,
                      'title': 'Coffee',
                      'categoryName': 'Food',
                      'createNewCategory': false,
                      'newCategoryName': null,
                      'walletName': 'Cash',
                      'date': '2026-07-31',
                      'note': null,
                    },
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final response = await client.sendMessage(
        userMessage: 'coffee 450',
        history: [],
        categoryNames: ['Food', 'Transport'],
        walletNamesWithCurrencies: {'Cash': 'USD', 'Bank': 'USD'},
        defaultWalletName: 'Cash',
        currentDate: '2026-07-31',
      );

      expect(response.assistantMessage, 'Here is your expense');
      expect(response.draft, isNotNull);
      expect(response.draft!.amount, 450.0);
      expect(response.draft!.title, 'Coffee');
    });

    test('with ocrText prepends receipt contents to user message', () async {
      String? capturedUserContent;
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        // The last message is the user's (combined) message
        capturedUserContent = messages.last['content'] as String;

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'assistantMessage': 'Parsed receipt',
                    'draft': {
                      'income': false,
                      'amount': 5.78,
                      'title': 'Walmart',
                      'categoryName': 'Food',
                      'createNewCategory': false,
                      'newCategoryName': null,
                      'walletName': 'Cash',
                      'date': '2026-07-31',
                      'note': null,
                    },
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      await client.sendMessage(
        userMessage: 'split with John',
        ocrText: 'Walmart\nMilk \$3.49\nTotal \$5.78',
        history: [],
        categoryNames: ['Food'],
        walletNamesWithCurrencies: {'Cash': 'USD'},
        defaultWalletName: 'Cash',
        currentDate: '2026-07-31',
      );

      expect(
        capturedUserContent,
        'Receipt contents:\nWalmart\nMilk \$3.49\nTotal \$5.78\n\nUser message: split with John',
      );
    });

    test('without ocrText works same as V1', () async {
      String? capturedUserContent;
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        capturedUserContent = messages.last['content'] as String;

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'assistantMessage': 'Got it',
                    'draft': {
                      'income': false,
                      'amount': 50.0,
                      'title': 'Lunch',
                      'categoryName': 'Food',
                      'createNewCategory': false,
                      'newCategoryName': null,
                      'walletName': 'Cash',
                      'date': '2026-07-31',
                      'note': null,
                    },
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      await client.sendMessage(
        userMessage: 'lunch 50',
        history: [],
        categoryNames: ['Food'],
        walletNamesWithCurrencies: {'Cash': 'USD'},
        defaultWalletName: 'Cash',
        currentDate: '2026-07-31',
      );

      expect(capturedUserContent, 'lunch 50');
      expect(capturedUserContent, isNot(contains('Receipt contents')));
    });

    test('with null ocrText works same as V1', () async {
      String? capturedUserContent;
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        capturedUserContent = messages.last['content'] as String;

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'assistantMessage': 'Done',
                    'draft': {
                      'income': false,
                      'amount': 100.0,
                      'title': 'Test',
                      'categoryName': 'Food',
                      'createNewCategory': false,
                      'newCategoryName': null,
                      'walletName': 'Cash',
                      'date': '2026-07-31',
                      'note': null,
                    },
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      await client.sendMessage(
        userMessage: 'test 100',
        ocrText: null,
        history: [],
        categoryNames: ['Food'],
        walletNamesWithCurrencies: {'Cash': 'USD'},
        defaultWalletName: 'Cash',
        currentDate: '2026-07-31',
      );

      expect(capturedUserContent, 'test 100');
    });

    test('throws auth exception on 401', () async {
      final mockClient = MockClient((_) async => http.Response('Unauthorized', 401));

      final client = HttpOpenRouterClient(
        apiKey: 'bad-key',
        httpClient: mockClient,
      );

      expect(
        () => client.sendMessage(
          userMessage: 'test',
          history: [],
          categoryNames: [],
          walletNamesWithCurrencies: {},
          defaultWalletName: 'Default',
          currentDate: '2026-07-31',
        ),
        throwsA(isA<OpenRouterAuthException>()),
      );
    });

    test('throws rate limit exception on 429', () async {
      final mockClient = MockClient((_) async => http.Response('Rate limited', 429));

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      expect(
        () => client.sendMessage(
          userMessage: 'test',
          history: [],
          categoryNames: [],
          walletNamesWithCurrencies: {},
          defaultWalletName: 'Default',
          currentDate: '2026-07-31',
        ),
        throwsA(isA<OpenRouterRateLimitException>()),
      );
    });

    test('falls back to second model on primary failure', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        // Parse request body to check which model is being called
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final model = body['model'] as String;

        if (model == 'openai/gpt-oss-20b:free' && callCount == 1) {
          return http.Response('Server error', 500);
        }

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'assistantMessage': 'Fallback worked',
                    'draft': {
                      'income': false,
                      'amount': 100.0,
                      'title': 'Test',
                      'categoryName': 'Food',
                      'createNewCategory': false,
                      'newCategoryName': null,
                      'walletName': 'Cash',
                      'date': '2026-07-31',
                      'note': null,
                    },
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final client = HttpOpenRouterClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final response = await client.sendMessage(
        userMessage: 'test',
        history: [],
        categoryNames: [],
        walletNamesWithCurrencies: {},
        defaultWalletName: 'Default',
        currentDate: '2026-07-31',
      );

      expect(callCount, 2);
      expect(response.assistantMessage, 'Fallback worked');
    });
  });
}
