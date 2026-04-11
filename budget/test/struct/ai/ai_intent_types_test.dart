import 'package:budget/database/tables.dart';
import 'package:budget/struct/ai/ai_intent_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiExecutionResult', () {
    test('success result with all fields', () {
      final result = AiExecutionResult(
        success: true,
        message: 'Added ₹1,200 expense to Groceries',
        actionType: 'transaction',
        detailRoute: '/transaction/123',
        createdObject: {'transactionPk': '123'},
      );
      expect(result.success, true);
      expect(result.message, 'Added ₹1,200 expense to Groceries');
      expect(result.actionType, 'transaction');
      expect(result.detailRoute, '/transaction/123');
      expect(result.createdObject, isNotNull);
    });

    test('failure result with minimal fields', () {
      final result = AiExecutionResult(
        success: false,
        message: 'Something went wrong',
      );
      expect(result.success, false);
      expect(result.message, 'Something went wrong');
      expect(result.actionType, isNull);
      expect(result.detailRoute, isNull);
      expect(result.createdObject, isNull);
    });

    test('success result with only required fields', () {
      final result = AiExecutionResult(success: true);
      expect(result.success, true);
      expect(result.message, isNull);
    });
  });

  group('AiIntent subclasses', () {
    test('AddTransactionIntent defaults', () {
      final intent = AddTransactionIntent(rawInput: 'add 500 coffee');
      expect(intent.rawInput, 'add 500 coffee');
      expect(intent.isIncome, false);
      expect(intent.name, isNull);
      expect(intent.amount, isNull);
    });

    test('AddTransactionIntent with all fields', () {
      final intent = AddTransactionIntent(
        rawInput: 'Netflix 499 monthly',
        name: 'Netflix',
        amount: 499,
        categoryName: 'Entertainment',
        isIncome: false,
        type: TransactionSpecialType.subscription,
        reoccurrence: BudgetReoccurence.monthly,
        periodLength: 1,
        walletName: 'Main',
        note: 'Netflix subscription',
      );
      expect(intent.name, 'Netflix');
      expect(intent.amount, 499);
      expect(intent.type, TransactionSpecialType.subscription);
      expect(intent.reoccurrence, BudgetReoccurence.monthly);
    });

    test('AddBudgetIntent defaults', () {
      final intent = AddBudgetIntent(rawInput: 'monthly food budget 15k');
      expect(intent.reoccurrence, BudgetReoccurence.monthly);
      expect(intent.periodLength, 1);
    });

    test('AddObjectiveIntent defaults', () {
      final intent = AddObjectiveIntent(rawInput: 'save 50k for vacation');
      expect(intent.type, ObjectiveType.goal);
      expect(intent.isIncome, false);
    });

    test('QuerySpendingIntent with period', () {
      final intent = QuerySpendingIntent(
        rawInput: 'how much did I spend this month',
        period: 'this month',
      );
      expect(intent.period, 'this month');
      expect(intent.categoryName, isNull);
    });

    test('QueryBudgetRemainingIntent with budgetName', () {
      final intent = QueryBudgetRemainingIntent(
        rawInput: 'how much left in food budget',
        budgetName: 'Food',
      );
      expect(intent.budgetName, 'Food');
    });

    test('QueryNetWorthIntent', () {
      final intent = QueryNetWorthIntent(rawInput: "what's my net worth");
      expect(intent.rawInput, "what's my net worth");
    });

    test('NavigateIntent with target', () {
      final intent = NavigateIntent(
        rawInput: 'show my subscriptions',
        target: 'subscriptions',
      );
      expect(intent.target, 'subscriptions');
    });

    test('PayTransactionIntent with action', () {
      final intent = PayTransactionIntent(
        rawInput: 'pay my Netflix subscription',
        transactionName: 'Netflix',
        action: 'pay',
      );
      expect(intent.transactionName, 'Netflix');
      expect(intent.action, 'pay');
    });

    test('UnclearIntent with clarification', () {
      final intent = UnclearIntent(
        rawInput: 'asdfgh',
        clarificationNeeded: 'Could not parse intent',
      );
      expect(intent.clarificationNeeded, 'Could not parse intent');
    });
  });
}
