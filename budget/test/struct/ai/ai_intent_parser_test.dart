import 'package:budget/database/tables.dart';
import 'package:budget/struct/ai/ai_intent_parser.dart';
import 'package:budget/struct/ai/ai_intent_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiIntentParser', () {
    late AiIntentParser parser;

    setUp(() {
      parser = AiIntentParser();
    });

    group('parseResponse - AddTransactionIntent', () {
      test('parses valid AddTransactionIntent from clean JSON', () {
        final rawOutput =
            '{"intent":"AddTransactionIntent","name":"Coffee","amount":500,"categoryName":"Food","isIncome":false}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<AddTransactionIntent>());
        final addIntent = intent as AddTransactionIntent;
        expect(addIntent.name, 'Coffee');
        expect(addIntent.amount, 500);
        expect(addIntent.categoryName, 'Food');
        expect(addIntent.isIncome, false);
      });

      test('parses AddTransactionIntent with all fields', () {
        final rawOutput = '''
        {"intent":"AddTransactionIntent","name":"Netflix","amount":499,"categoryName":"Entertainment","isIncome":false,"type":"subscription","reoccurrence":"monthly","periodLength":1,"date":"2024-01-15","walletName":"Main","note":"Monthly subscription"}
        ''';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<AddTransactionIntent>());
        final addIntent = intent as AddTransactionIntent;
        expect(addIntent.name, 'Netflix');
        expect(addIntent.amount, 499);
        expect(addIntent.categoryName, 'Entertainment');
        expect(addIntent.type, TransactionSpecialType.subscription);
        expect(addIntent.reoccurrence, BudgetReoccurence.monthly);
        expect(addIntent.periodLength, 1);
        expect(addIntent.date, '2024-01-15');
        expect(addIntent.walletName, 'Main');
        expect(addIntent.note, 'Monthly subscription');
      });

      test('parses AddTransactionIntent as income', () {
        final rawOutput =
            '{"intent":"AddTransactionIntent","name":"Salary","amount":5000,"categoryName":"Income","isIncome":true}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<AddTransactionIntent>());
        final addIntent = intent as AddTransactionIntent;
        expect(addIntent.isIncome, true);
      });

      test('parses AddTransactionIntent with credit type', () {
        final rawOutput =
            '{"intent":"AddTransactionIntent","name":"Lent to John","amount":1000,"type":"credit","isIncome":false}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<AddTransactionIntent>());
        final addIntent = intent as AddTransactionIntent;
        expect(addIntent.type, TransactionSpecialType.credit);
      });
    });

    group('parseResponse - AddBudgetIntent', () {
      test('parses valid AddBudgetIntent', () {
        final rawOutput =
            '{"intent":"AddBudgetIntent","name":"Food","amount":15000,"reoccurrence":"monthly","periodLength":1,"categoryNames":["Food","Dining"]}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<AddBudgetIntent>());
        final budgetIntent = intent as AddBudgetIntent;
        expect(budgetIntent.name, 'Food');
        expect(budgetIntent.amount, 15000);
        expect(budgetIntent.reoccurrence, BudgetReoccurence.monthly);
        expect(budgetIntent.periodLength, 1);
        expect(budgetIntent.categoryNames, ['Food', 'Dining']);
      });

      test('parses AddBudgetIntent with wallet', () {
        final rawOutput =
            '{"intent":"AddBudgetIntent","name":"Entertainment","amount":5000,"reoccurrence":"weekly","periodLength":1,"walletName":"Main"}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<AddBudgetIntent>());
        final budgetIntent = intent as AddBudgetIntent;
        expect(budgetIntent.walletName, 'Main');
        expect(budgetIntent.reoccurrence, BudgetReoccurence.weekly);
      });

      test('parses AddBudgetIntent defaults for missing optional fields', () {
        final rawOutput =
            '{"intent":"AddBudgetIntent","name":"Test","amount":100}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<AddBudgetIntent>());
        final budgetIntent = intent as AddBudgetIntent;
        expect(budgetIntent.reoccurrence, BudgetReoccurence.monthly);
        expect(budgetIntent.periodLength, 1);
        expect(budgetIntent.categoryNames, isNull);
      });
    });

    group('parseResponse - AddObjectiveIntent', () {
      test('parses valid AddObjectiveIntent for goal', () {
        final rawOutput =
            '{"intent":"AddObjectiveIntent","type":"goal","name":"Vacation","amount":50000,"isIncome":false}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<AddObjectiveIntent>());
        final objIntent = intent as AddObjectiveIntent;
        expect(objIntent.type, ObjectiveType.goal);
        expect(objIntent.name, 'Vacation');
        expect(objIntent.amount, 50000);
        expect(objIntent.isIncome, false);
      });

      test('parses AddObjectiveIntent for loan', () {
        final rawOutput =
            '{"intent":"AddObjectiveIntent","type":"loan","name":"Emergency Fund","amount":10000,"isIncome":true,"endDate":"2024-12-31"}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<AddObjectiveIntent>());
        final objIntent = intent as AddObjectiveIntent;
        expect(objIntent.type, ObjectiveType.loan);
        expect(objIntent.endDate, '2024-12-31');
      });

      test('parses AddObjectiveIntent defaults to goal when type missing', () {
        final rawOutput =
            '{"intent":"AddObjectiveIntent","name":"Test","amount":100}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<AddObjectiveIntent>());
        final objIntent = intent as AddObjectiveIntent;
        expect(objIntent.type, ObjectiveType.goal);
      });
    });

    group('parseResponse - QuerySpendingIntent', () {
      test('parses valid QuerySpendingIntent with period', () {
        final rawOutput =
            '{"intent":"QuerySpendingIntent","period":"this month"}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<QuerySpendingIntent>());
        final queryIntent = intent as QuerySpendingIntent;
        expect(queryIntent.period, 'this month');
      });

      test('parses QuerySpendingIntent with category filter', () {
        final rawOutput =
            '{"intent":"QuerySpendingIntent","period":"this week","categoryName":"Food"}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<QuerySpendingIntent>());
        final queryIntent = intent as QuerySpendingIntent;
        expect(queryIntent.categoryName, 'Food');
      });

      test('parses QuerySpendingIntent with income filter', () {
        final rawOutput =
            '{"intent":"QuerySpendingIntent","period":"this month","isIncome":true}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<QuerySpendingIntent>());
        final queryIntent = intent as QuerySpendingIntent;
        expect(queryIntent.isIncome, true);
      });
    });

    group('parseResponse - QueryBudgetRemainingIntent', () {
      test('parses valid QueryBudgetRemainingIntent', () {
        final rawOutput =
            '{"intent":"QueryBudgetRemainingIntent","budgetName":"Food"}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<QueryBudgetRemainingIntent>());
        final queryIntent = intent as QueryBudgetRemainingIntent;
        expect(queryIntent.budgetName, 'Food');
      });
    });

    group('parseResponse - QueryNetWorthIntent', () {
      test('parses valid QueryNetWorthIntent', () {
        final rawOutput = '{"intent":"QueryNetWorthIntent"}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<QueryNetWorthIntent>());
      });
    });

    group('parseResponse - NavigateIntent', () {
      test('parses NavigateIntent for subscriptions', () {
        final rawOutput =
            '{"intent":"NavigateIntent","target":"subscriptions"}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<NavigateIntent>());
        final navIntent = intent as NavigateIntent;
        expect(navIntent.target, 'subscriptions');
      });

      test('normalizes common navigation target variations', () {
        final intent = parser.parseResponse(
            '{"intent":"NavigateIntent","target":"recurring payments"}');
        expect((intent as NavigateIntent).target, 'subscriptions');
      });

      test('normalizes goals target', () {
        final intent = parser.parseResponse(
            '{"intent":"NavigateIntent","target":"savings goals"}');
        expect((intent as NavigateIntent).target, 'goals');
      });

      test('normalizes budgets target', () {
        final intent = parser.parseResponse(
            '{"intent":"NavigateIntent","target":"spending limits"}');
        expect((intent as NavigateIntent).target, 'budgets');
      });

      test('defaults to home for unknown target', () {
        final intent = parser
            .parseResponse('{"intent":"NavigateIntent","target":"unknown"}');
        expect((intent as NavigateIntent).target, 'home');
      });
    });

    group('parseResponse - PayTransactionIntent', () {
      test('parses valid PayTransactionIntent', () {
        final rawOutput =
            '{"intent":"PayTransactionIntent","transactionName":"Netflix","action":"pay"}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<PayTransactionIntent>());
        final payIntent = intent as PayTransactionIntent;
        expect(payIntent.transactionName, 'Netflix');
        expect(payIntent.action, 'pay');
      });

      test('parses PayTransactionIntent with skip action', () {
        final rawOutput =
            '{"intent":"PayTransactionIntent","transactionName":"Gym","action":"skip"}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent, isA<PayTransactionIntent>());
        final payIntent = intent as PayTransactionIntent;
        expect(payIntent.action, 'skip');
      });
    });

    group('parseResponse - UnclearIntent', () {
      test('returns UnclearIntent for empty response', () {
        final intent = parser.parseResponse('');
        expect(intent, isA<UnclearIntent>());
      });

      test('returns UnclearIntent for plain text without JSON', () {
        final intent = parser.parseResponse('Hello, how can I help you?');
        expect(intent, isA<UnclearIntent>());
      });

      test('returns UnclearIntent for malformed JSON', () {
        final intent =
            parser.parseResponse('{"intent":"AddTransaction","broken json}');
        expect(intent, isA<UnclearIntent>());
      });

      test('returns UnclearIntent for JSON without intent field', () {
        final intent = parser.parseResponse('{"name":"Test","amount":100}');
        expect(intent, isA<UnclearIntent>());
      });

      test('returns UnclearIntent for unknown intent type', () {
        final intent = parser.parseResponse('{"intent":"UnknownIntent"}');
        expect(intent, isA<UnclearIntent>());
      });

      test('returns UnclearIntent when JSON extraction fails', () {
        final intent = parser
            .parseResponse('Some text before {"intent" valid but unclosed');
        expect(intent, isA<UnclearIntent>());
      });
    });

    group('parseResponse - JSON extraction', () {
      test('extracts JSON from text with surrounding prose', () {
        final rawOutput = '''
        Sure! Let me help you add that transaction:
        {"intent":"AddTransactionIntent","name":"Coffee","amount":5,"categoryName":"Food"}
        
        Is there anything else you'd like to do?
        ''';
        final intent = parser.parseResponse(rawOutput);
        expect(intent, isA<AddTransactionIntent>());
        expect((intent as AddTransactionIntent).name, 'Coffee');
      });

      test('extracts JSON from markdown code block', () {
        final rawOutput = '''
        Here's your transaction:
        ```json
        {"intent":"AddTransactionIntent","name":"Lunch","amount":25,"categoryName":"Dining"}
        ```
        ''';
        final intent = parser.parseResponse(rawOutput);
        expect(intent, isA<AddTransactionIntent>());
        expect((intent as AddTransactionIntent).amount, 25);
      });

      test('handles nested braces in JSON values', () {
        final rawOutput =
            '{"intent":"AddTransactionIntent","name":"Test with quotes","amount":10}';
        final intent = parser.parseResponse(rawOutput);
        expect(intent, isA<AddTransactionIntent>());
      });

      test('handles number as string in amount field', () {
        final rawOutput =
            '{"intent":"AddTransactionIntent","name":"Test","amount":"500"}';
        final intent = parser.parseResponse(rawOutput);
        expect(intent, isA<AddTransactionIntent>());
        expect((intent as AddTransactionIntent).amount, 500);
      });

      test('handles integer amount', () {
        final rawOutput =
            '{"intent":"AddTransactionIntent","name":"Test","amount":500}';
        final intent = parser.parseResponse(rawOutput);
        expect(intent, isA<AddTransactionIntent>());
        expect((intent as AddTransactionIntent).amount, 500);
      });
    });

    group('parseResponse - rawInput preservation', () {
      test('preserves original input in rawInput field', () {
        final rawInput = 'add 500 rupees for groceries';
        final rawOutput =
            '{"intent":"AddTransactionIntent","name":"Groceries","amount":500}';
        final intent = parser.parseResponse(rawOutput, rawInput: rawInput);

        expect(intent.rawInput, rawInput);
      });

      test('uses rawOutput as rawInput when rawInput not provided', () {
        final rawOutput = '{"intent":"QueryNetWorthIntent"}';
        final intent = parser.parseResponse(rawOutput);

        expect(intent.rawInput, rawOutput);
      });
    });

    group('Transaction types parsing', () {
      test('parses all transaction special types', () {
        final types = [
          'upcoming',
          'subscription',
          'repetitive',
          'credit',
          'debt'
        ];
        final expectedTypes = [
          TransactionSpecialType.upcoming,
          TransactionSpecialType.subscription,
          TransactionSpecialType.repetitive,
          TransactionSpecialType.credit,
          TransactionSpecialType.debt,
        ];

        for (int i = 0; i < types.length; i++) {
          final rawOutput =
              '{"intent":"AddTransactionIntent","name":"Test","amount":100,"type":"${types[i]}"}';
          final intent = parser.parseResponse(rawOutput);
          expect(intent, isA<AddTransactionIntent>());
          expect((intent as AddTransactionIntent).type, expectedTypes[i]);
        }
      });
    });

    group('Reoccurrence parsing', () {
      test('parses all budget reoccurrence types', () {
        final recurrences = ['daily', 'weekly', 'monthly', 'yearly', 'custom'];
        final expectedRecurrences = [
          BudgetReoccurence.daily,
          BudgetReoccurence.weekly,
          BudgetReoccurence.monthly,
          BudgetReoccurence.yearly,
          BudgetReoccurence.custom,
        ];

        for (int i = 0; i < recurrences.length; i++) {
          final rawOutput =
              '{"intent":"AddBudgetIntent","name":"Test","amount":100,"reoccurrence":"${recurrences[i]}"}';
          final intent = parser.parseResponse(rawOutput);
          expect(intent, isA<AddBudgetIntent>());
          expect(
              (intent as AddBudgetIntent).reoccurrence, expectedRecurrences[i]);
        }
      });
    });
  });
}
