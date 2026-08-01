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
  });

  group('HttpOpenRouterClient', () {
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
