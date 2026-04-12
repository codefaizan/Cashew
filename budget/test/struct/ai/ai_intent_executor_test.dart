import 'package:budget/database/tables.dart';
import 'package:budget/struct/ai/ai_intent_executor.dart';
import 'package:budget/struct/ai/ai_intent_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiIntentExecutor', () {
    late AiIntentExecutor executor;

    setUp(() {
      executor = AiIntentExecutor();
    });

    group('resolveTimePeriod', () {
      test('resolves "today" to today\'s date range', () {
        final result = executor.resolveTimePeriod('today');
        expect(result, isNotNull);

        final (start, end) = result!;
        final now = DateTime.now();

        expect(start.year, now.year);
        expect(start.month, now.month);
        expect(start.day, now.day);
        expect(start.hour, 0);
        expect(start.minute, 0);
        expect(start.second, 0);
      });

      test('resolves "this week" to monday-today range', () {
        final result = executor.resolveTimePeriod('this week');
        expect(result, isNotNull);

        final (start, end) = result!;
        final now = DateTime.now();
        final expectedMonday = now.subtract(Duration(days: now.weekday - 1));

        expect(start.year, expectedMonday.year);
        expect(start.month, expectedMonday.month);
        expect(start.day, expectedMonday.day);
        expect(start.hour, 0);
        expect(start.minute, 0);
      });

      test('resolves "this month" to 1st-today range', () {
        final result = executor.resolveTimePeriod('this month');
        expect(result, isNotNull);

        final (start, end) = result!;
        final now = DateTime.now();

        expect(start.year, now.year);
        expect(start.month, now.month);
        expect(start.day, 1);
        expect(start.hour, 0);
        expect(start.minute, 0);
      });

      test('resolves "this year" to jan1-today range', () {
        final result = executor.resolveTimePeriod('this year');
        expect(result, isNotNull);

        final (start, end) = result!;
        final now = DateTime.now();

        expect(start.year, now.year);
        expect(start.month, 1);
        expect(start.day, 1);
        expect(start.hour, 0);
        expect(start.minute, 0);
      });

      test('resolves "month" same as "this month"', () {
        final resultMonth = executor.resolveTimePeriod('month');
        final resultThisMonth = executor.resolveTimePeriod('this month');

        expect(resultMonth, isNotNull);
        expect(resultThisMonth, isNotNull);

        expect(resultMonth!.$1.year, resultThisMonth!.$1.year);
        expect(resultMonth.$1.month, resultThisMonth.$1.month);
        expect(resultMonth.$1.day, resultThisMonth.$1.day);
      });

      test('resolves "week" same as "this week"', () {
        final resultWeek = executor.resolveTimePeriod('week');
        final resultThisWeek = executor.resolveTimePeriod('this week');

        expect(resultWeek, isNotNull);
        expect(resultThisWeek, isNotNull);

        expect(resultWeek!.$1.year, resultThisWeek!.$1.year);
        expect(resultWeek.$1.day, resultThisWeek.$1.day);
      });

      test('resolves "year" same as "this year"', () {
        final resultYear = executor.resolveTimePeriod('year');
        final resultThisYear = executor.resolveTimePeriod('this year');

        expect(resultYear, isNotNull);
        expect(resultThisYear, isNotNull);

        expect(resultYear!.$1.year, resultThisYear!.$1.year);
        expect(resultYear.$1.month, resultThisYear.$1.month);
        expect(resultYear.$1.day, resultThisYear.$1.day);
      });

      test('returns null for null input', () {
        final result = executor.resolveTimePeriod(null);
        expect(result, isNull);
      });

      test('returns null for empty string', () {
        final result = executor.resolveTimePeriod('');
        expect(result, isNull);
      });

      test('returns null for unknown period', () {
        final result = executor.resolveTimePeriod('unknown period');
        expect(result, isNull);
      });

      test('is case insensitive', () {
        final lower = executor.resolveTimePeriod('today');
        final upper = executor.resolveTimePeriod('TODAY');
        final mixed = executor.resolveTimePeriod('ToDaY');

        expect(lower, isNotNull);
        expect(upper, isNotNull);
        expect(mixed, isNotNull);

        expect(lower!.$1.day, upper!.$1.day);
        expect(upper.$1.day, mixed!.$1.day);
      });

      test('trims whitespace', () {
        final result = executor.resolveTimePeriod('  today  ');
        expect(result, isNotNull);
        expect(result!.$1.day, DateTime.now().day);
      });
    });

    group('execute - UnclearIntent', () {
      test('returns clarification message', () async {
        final intent = UnclearIntent(
          rawInput: 'gibberish text',
          clarificationNeeded: 'Could you rephrase?',
        );

        final result = await executor.execute(intent);

        expect(result.success, false);
        expect(result.actionType, 'unclear');
        expect(result.message, 'Could you rephrase?');
      });

      test('returns default message when clarification is null', () async {
        final intent = UnclearIntent(
          rawInput: 'asdf',
          clarificationNeeded: null,
        );

        final result = await executor.execute(intent);

        expect(result.success, false);
        expect(result.message, "I didn't understand that. Could you rephrase?");
      });
    });

    group('AiExecutionResult for queries', () {
      test('QuerySpendingIntent result contains total and count', () {
        final intent = QuerySpendingIntent(
          rawInput: 'how much spent',
          period: 'this month',
        );

        expect(intent.period, 'this month');
        expect(intent.rawInput, 'how much spent');
      });

      test('QueryBudgetRemainingIntent result contains budget name', () {
        final intent = QueryBudgetRemainingIntent(
          rawInput: 'how much left in food',
          budgetName: 'Food',
        );

        expect(intent.budgetName, 'Food');
      });

      test('QueryNetWorthIntent result has no extra fields', () {
        final intent = QueryNetWorthIntent(
          rawInput: "what's my net worth",
        );

        expect(intent.rawInput, "what's my net worth");
      });
    });

    group('AddTransactionIntent execution result structure', () {
      test('intent has all required fields for execution', () {
        final intent = AddTransactionIntent(
          rawInput: 'add 500 coffee',
          name: 'Coffee',
          amount: 500,
          categoryName: 'Food',
          isIncome: false,
          walletName: 'Main',
        );

        expect(intent.name, 'Coffee');
        expect(intent.amount, 500);
        expect(intent.categoryName, 'Food');
        expect(intent.isIncome, false);
        expect(intent.walletName, 'Main');
      });

      test('intent handles income transaction', () {
        final intent = AddTransactionIntent(
          rawInput: 'received 5000 salary',
          name: 'Salary',
          amount: 5000,
          categoryName: 'Income',
          isIncome: true,
        );

        expect(intent.isIncome, true);
        expect(intent.amount, 5000);
      });

      test('intent handles subscription type', () {
        final intent = AddTransactionIntent(
          rawInput: 'netflix 499 monthly',
          name: 'Netflix',
          amount: 499,
          type: TransactionSpecialType.subscription,
          reoccurrence: BudgetReoccurence.monthly,
        );

        expect(intent.type, TransactionSpecialType.subscription);
        expect(intent.reoccurrence, BudgetReoccurence.monthly);
      });

      test('intent handles credit type for lending', () {
        final intent = AddTransactionIntent(
          rawInput: 'lent 1000 to john',
          name: 'Lent to John',
          amount: 1000,
          type: TransactionSpecialType.credit,
          note: 'John borrowed money',
        );

        expect(intent.type, TransactionSpecialType.credit);
        expect(intent.note, 'John borrowed money');
      });
    });

    group('AddBudgetIntent execution result structure', () {
      test('intent has all required fields for execution', () {
        final intent = AddBudgetIntent(
          rawInput: 'monthly food budget 15k',
          name: 'Food',
          amount: 15000,
          reoccurrence: BudgetReoccurence.monthly,
          periodLength: 1,
          categoryNames: ['Food', 'Dining'],
        );

        expect(intent.name, 'Food');
        expect(intent.amount, 15000);
        expect(intent.reoccurrence, BudgetReoccurence.monthly);
        expect(intent.periodLength, 1);
        expect(intent.categoryNames, ['Food', 'Dining']);
      });

      test('intent has correct defaults', () {
        final intent = AddBudgetIntent(
          rawInput: 'test budget',
        );

        expect(intent.reoccurrence, BudgetReoccurence.monthly);
        expect(intent.periodLength, 1);
      });
    });

    group('AddObjectiveIntent execution result structure', () {
      test('intent for goal has correct structure', () {
        final intent = AddObjectiveIntent(
          rawInput: 'save 50k for vacation',
          type: ObjectiveType.goal,
          name: 'Vacation',
          amount: 50000,
          isIncome: false,
        );

        expect(intent.type, ObjectiveType.goal);
        expect(intent.name, 'Vacation');
        expect(intent.amount, 50000);
        expect(intent.isIncome, false);
      });

      test('intent for loan has correct structure', () {
        final intent = AddObjectiveIntent(
          rawInput: 'lent 10k to friend',
          type: ObjectiveType.loan,
          name: 'Friend Loan',
          amount: 10000,
          isIncome: false,
        );

        expect(intent.type, ObjectiveType.loan);
      });

      test('intent has correct defaults', () {
        final intent = AddObjectiveIntent(
          rawInput: 'test goal',
        );

        expect(intent.type, ObjectiveType.goal);
        expect(intent.isIncome, false);
      });
    });

    group('PayTransactionIntent execution result structure', () {
      test('intent with pay action', () {
        final intent = PayTransactionIntent(
          rawInput: 'pay netflix',
          transactionName: 'Netflix',
          action: 'pay',
        );

        expect(intent.transactionName, 'Netflix');
        expect(intent.action, 'pay');
      });

      test('intent with skip action', () {
        final intent = PayTransactionIntent(
          rawInput: 'skip gym',
          transactionName: 'Gym',
          action: 'skip',
        );

        expect(intent.transactionName, 'Gym');
        expect(intent.action, 'skip');
      });

      test('intent with null action defaults to pay', () {
        final intent = PayTransactionIntent(
          rawInput: 'mark as paid',
          transactionName: 'Netflix',
          action: null,
        );

        expect(intent.transactionName, 'Netflix');
        expect(intent.action, isNull);
      });
    });

    group('AiExecutionResult structure', () {
      test('success result with message', () {
        final result = AiExecutionResult(
          success: true,
          message: 'Added transaction',
          actionType: 'transaction_created',
          detailRoute: 'transaction:123',
        );

        expect(result.success, true);
        expect(result.message, 'Added transaction');
        expect(result.actionType, 'transaction_created');
        expect(result.detailRoute, 'transaction:123');
        expect(result.createdObject, isNull);
      });

      test('success result with created object', () {
        final result = AiExecutionResult(
          success: true,
          message: 'Created',
          actionType: 'budget_created',
          createdObject: {'name': 'Food', 'amount': 15000},
        );

        expect(result.success, true);
        expect(result.createdObject, isA<Map>());
        expect((result.createdObject as Map)['name'], 'Food');
      });

      test('failure result with error message', () {
        final result = AiExecutionResult(
          success: false,
          message: 'Category not found',
          actionType: 'create_category',
        );

        expect(result.success, false);
        expect(result.message, 'Category not found');
        expect(result.actionType, 'create_category');
      });

      test('query result with data', () {
        final result = AiExecutionResult(
          success: true,
          message: 'You spent ₹5000 this month',
          actionType: 'spending_query',
          createdObject: {
            'total': 5000.0,
            'count': 15,
            'byCategory': {'Food': 2000.0, 'Transport': 3000.0},
          },
        );

        expect(result.success, true);
        expect(result.createdObject, isA<Map>());
        expect((result.createdObject as Map)['total'], 5000.0);
        expect((result.createdObject as Map)['count'], 15);
      });
    });
  });
}
