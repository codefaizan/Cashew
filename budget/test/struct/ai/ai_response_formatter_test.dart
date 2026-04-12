import 'package:budget/database/tables.dart';
import 'package:budget/struct/ai/ai_intent_types.dart';
import 'package:budget/struct/ai/ai_response_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiResponseFormatter', () {
    group('format() for transaction', () {
      test('formats expense transaction', () {
        final formatter = AiResponseFormatter();
        final transaction = Transaction(
          transactionPk: '123',
          name: 'Coffee',
          amount: -1200,
          note: '',
          categoryFk: '1',
          subCategoryFk: null,
          walletFk: '1',
          dateCreated: DateTime.now(),
          endDate: null,
          dateTimeModified: null,
          income: false,
          paid: false,
          skipPaid: false,
          type: null,
          reoccurrence: null,
          periodLength: null,
          methodAdded: null,
          createdAnotherFutureTransaction: null,
          upcomingTransactionNotification: null,
          originalDateDue: null,
          sharedKey: null,
          sharedOldKey: null,
          transactionOwnerEmail: null,
          transactionOriginalOwnerEmail: null,
          sharedStatus: null,
          sharedDateUpdated: null,
          sharedReferenceBudgetPk: null,
          objectiveFk: null,
          objectiveLoanFk: null,
          budgetFksExclude: null,
          pairedTransactionFk: null,
        );

        final result = AiExecutionResult(
          success: true,
          actionType: 'transaction_created',
          detailRoute: 'transaction:123',
          createdObject: transaction,
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('expense'));
        expect(formatted, contains('Coffee'));
      });

      test('formats income transaction', () {
        final formatter = AiResponseFormatter();
        final transaction = Transaction(
          transactionPk: '456',
          name: 'Salary',
          amount: 50000,
          note: '',
          categoryFk: '2',
          subCategoryFk: null,
          walletFk: '1',
          dateCreated: DateTime.now(),
          endDate: null,
          dateTimeModified: null,
          income: true,
          paid: false,
          skipPaid: false,
          type: null,
          reoccurrence: null,
          periodLength: null,
          methodAdded: null,
          createdAnotherFutureTransaction: null,
          upcomingTransactionNotification: null,
          originalDateDue: null,
          sharedKey: null,
          sharedOldKey: null,
          transactionOwnerEmail: null,
          transactionOriginalOwnerEmail: null,
          sharedStatus: null,
          sharedDateUpdated: null,
          sharedReferenceBudgetPk: null,
          objectiveFk: null,
          objectiveLoanFk: null,
          budgetFksExclude: null,
          pairedTransactionFk: null,
        );

        final result = AiExecutionResult(
          success: true,
          actionType: 'transaction_created',
          detailRoute: 'transaction:456',
          createdObject: transaction,
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('income'));
        expect(formatted, contains('Salary'));
      });
    });

    group('format() for budget', () {
      test('formats budget creation', () {
        final formatter = AiResponseFormatter();
        final budget = Budget(
          budgetPk: '1',
          name: 'Food',
          amount: 15000,
          colour: null,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: 30)),
          walletFks: null,
          categoryFks: null,
          categoryFksExclude: null,
          income: false,
          archived: false,
          addedTransactionsOnly: false,
          periodLength: 1,
          reoccurrence: BudgetReoccurence.monthly,
          dateCreated: DateTime.now(),
          dateTimeModified: null,
          pinned: false,
          order: 0,
          walletFk: '1',
          budgetTransactionFilters: [
            BudgetTransactionFilters.defaultBudgetTransactionFilters
          ],
          memberTransactionFilters: null,
          sharedKey: null,
          sharedOwnerMember: null,
          sharedDateUpdated: null,
          sharedMembers: null,
          sharedAllMembersEver: null,
          isAbsoluteSpendingLimit: false,
        );

        final result = AiExecutionResult(
          success: true,
          actionType: 'budget_created',
          detailRoute: 'budget:Food',
          createdObject: budget,
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('Food'));
        expect(formatted, contains('monthly'));
      });
    });

    group('format() for objective', () {
      test('formats goal creation', () {
        final formatter = AiResponseFormatter();
        final objective = Objective(
          objectivePk: '1',
          type: ObjectiveType.goal,
          name: 'Vacation',
          amount: 50000,
          order: 0,
          colour: null,
          dateCreated: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: 365)),
          dateTimeModified: null,
          iconName: null,
          emojiIconName: null,
          income: false,
          pinned: true,
          archived: false,
          walletFk: '1',
        );

        final result = AiExecutionResult(
          success: true,
          actionType: 'goal_created',
          detailRoute: 'goal:Vacation',
          createdObject: objective,
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('Vacation'));
        expect(formatted, contains('save'));
      });

      test('formats loan creation', () {
        final formatter = AiResponseFormatter();
        final objective = Objective(
          objectivePk: '2',
          type: ObjectiveType.loan,
          name: 'Car Loan',
          amount: 500000,
          order: 0,
          colour: null,
          dateCreated: DateTime.now(),
          endDate: null,
          dateTimeModified: null,
          iconName: null,
          emojiIconName: null,
          income: false,
          pinned: true,
          archived: false,
          walletFk: '1',
        );

        final result = AiExecutionResult(
          success: true,
          actionType: 'loan_created',
          detailRoute: 'loan:Car Loan',
          createdObject: objective,
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('Car Loan'));
        expect(formatted, contains('loan'));
      });
    });

    group('format() for spending query', () {
      test('formats spending query with top categories', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'spending_query',
          createdObject: {
            'total': 12450.0,
            'count': 8,
            'byCategory': {
              'Groceries': 4200.0,
              'Dining': 3100.0,
              'Transport': 2000.0,
            },
            'startDate': DateTime.now(),
            'endDate': DateTime.now(),
          },
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('spent'));
        expect(formatted, contains('transactions'));
      });

      test('formats spending query without categories', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'spending_query',
          createdObject: {
            'total': 1000.0,
            'count': 2,
            'byCategory': <String, double>{},
            'startDate': DateTime.now(),
            'endDate': DateTime.now(),
          },
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('spent'));
        expect(formatted, isNot(contains('Top:')));
      });
    });

    group('format() for budget remaining query', () {
      test('formats budget remaining query', () {
        final formatter = AiResponseFormatter();
        final budget = Budget(
          budgetPk: '1',
          name: 'Food',
          amount: 15000,
          colour: null,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: 30)),
          walletFks: null,
          categoryFks: null,
          categoryFksExclude: null,
          income: false,
          archived: false,
          addedTransactionsOnly: false,
          periodLength: 1,
          reoccurrence: BudgetReoccurence.monthly,
          dateCreated: DateTime.now(),
          dateTimeModified: null,
          pinned: false,
          order: 0,
          walletFk: '1',
          budgetTransactionFilters: [
            BudgetTransactionFilters.defaultBudgetTransactionFilters
          ],
          memberTransactionFilters: null,
          sharedKey: null,
          sharedOwnerMember: null,
          sharedDateUpdated: null,
          sharedMembers: null,
          sharedAllMembersEver: null,
          isAbsoluteSpendingLimit: false,
        );

        final result = AiExecutionResult(
          success: true,
          actionType: 'budget_remaining_query',
          createdObject: {
            'budget': budget,
            'spent': 6500.0,
            'remaining': 8500.0,
            'percentUsed': 43.33,
          },
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('Food'));
        expect(formatted, contains('remaining'));
        expect(formatted, contains('%'));
      });
    });

    group('format() for net worth query', () {
      test('formats net worth query', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'net_worth_query',
          createdObject: {
            'total': 245000.0,
            'walletCount': 3,
          },
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('net worth'));
        expect(formatted, contains('accounts'));
      });
    });

    group('format() for navigation', () {
      test('formats navigation message', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'navigation',
          detailRoute: 'subscriptions',
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('Opening'));
        expect(formatted, contains('Subscriptions'));
      });
    });

    group('format() for pay', () {
      test('formats paid transaction', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'transaction_paid',
          detailRoute: 'transaction:Netflix',
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('paid'));
        expect(formatted, contains('Netflix'));
      });

      test('formats skipped transaction', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'transaction_skipped',
          detailRoute: 'transaction:Netflix',
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('Skipped'));
        expect(formatted, contains('Netflix'));
      });
    });

    group('format() for error', () {
      test('formats error message', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: false,
          message: 'Something went wrong. Please try again.',
        );

        final formatted = formatter.format(result);
        expect(formatted, 'Something went wrong. Please try again.');
      });

      test('formats fallback error message', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(success: false);

        final formatted = formatter.format(result);
        expect(formatted, 'Something went wrong. Please try again.');
      });
    });

    group('format() for unclear', () {
      test('formats unclear message', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: false,
          actionType: 'create_category',
          message: 'Category "Unknown" not found. Should I create it?',
        );

        final formatted = formatter.format(result);
        expect(formatted, contains('Should I create'));
      });

      test('formats fallback unclear message', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: false,
          message: "I didn't understand that. Could you rephrase?",
        );

        final formatted = formatter.format(result);
        expect(formatted, "I didn't understand that. Could you rephrase?");
      });
    });

    group('getViewAction()', () {
      test('returns action button for transaction', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'transaction_created',
          detailRoute: 'transaction:123',
        );

        final action = formatter.getViewAction(result);
        expect(action, isNotNull);
        expect(action!.label, 'View Transaction');
        expect(action.route, 'transaction:123');
      });

      test('returns action button for budget', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'budget_created',
          detailRoute: 'budget:Food',
        );

        final action = formatter.getViewAction(result);
        expect(action, isNotNull);
        expect(action!.label, 'View Budget');
      });

      test('returns action button for goal', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'goal_created',
          detailRoute: 'goal:Vacation',
        );

        final action = formatter.getViewAction(result);
        expect(action, isNotNull);
        expect(action!.label, 'View Goal');
      });

      test('returns action button for spending query', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'spending_query',
        );

        final action = formatter.getViewAction(result);
        expect(action, isNotNull);
        expect(action!.label, 'View Transactions');
        expect(action.route, '/transactions');
      });

      test('returns null for navigation', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'navigation',
          detailRoute: 'subscriptions',
        );

        final action = formatter.getViewAction(result);
        expect(action, isNull);
      });

      test('returns null when detailRoute is null', () {
        final formatter = AiResponseFormatter();
        final result = AiExecutionResult(
          success: true,
          actionType: 'transaction_created',
        );

        final action = formatter.getViewAction(result);
        expect(action, isNull);
      });
    });
  });
}
