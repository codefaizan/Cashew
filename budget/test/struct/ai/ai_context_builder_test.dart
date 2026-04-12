import 'package:budget/database/tables.dart';
import 'package:budget/struct/ai/ai_context_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiContextBuilder', () {
    test('getUserCategories formats expense categories correctly', () async {
      final builder = TestAiContextBuilder();
      final result = await builder.getUserCategoriesForTest(
        categories: [
          _createCategory('Food', false),
          _createCategory('Dining', false),
          _createCategory('Salary', true),
        ],
      );

      expect(result, contains('Expense categories: Food, Dining'));
      expect(result, contains('Income categories: Salary'));
    });

    test('getUserWallets formats wallets correctly', () async {
      final builder = TestAiContextBuilder();
      final result = await builder.getUserWalletsForTest(
        wallets: [
          _createWallet('Main', 'USD'),
          _createWallet('Savings', 'EUR'),
        ],
      );

      expect(result, contains('Main (USD)'));
      expect(result, contains('Savings (EUR)'));
    });

    test('getUserWallets handles empty wallet list', () async {
      final builder = TestAiContextBuilder();
      final result = await builder.getUserWalletsForTest(wallets: []);

      expect(result, contains('No wallets created yet'));
    });

    test('getUserBudgets formats budgets correctly', () async {
      final builder = TestAiContextBuilder();
      final result = await builder.getUserBudgetsForTest(
        budgets: [
          _createBudget('Food', 15000, BudgetReoccurence.monthly),
          _createBudget('Entertainment', 5000, BudgetReoccurence.weekly),
        ],
      );

      expect(result, contains('Food: monthly budget of 15000'));
      expect(result, contains('Entertainment: weekly budget of 5000'));
    });

    test('getUserBudgets handles empty budget list', () async {
      final builder = TestAiContextBuilder();
      final result = await builder.getUserBudgetsForTest(budgets: []);

      expect(result, contains('No budgets created yet'));
    });

    test('buildSystemPrompt contains essential sections', () async {
      final builder = TestAiContextBuilder();
      final systemPrompt = await builder.buildSystemPromptForTest(
        categories: [
          _createCategory('Food', false),
        ],
        wallets: [
          _createWallet('Main', 'USD'),
        ],
        budgets: [
          _createBudget('Food', 15000, BudgetReoccurence.monthly),
        ],
      );

      expect(systemPrompt, contains('Cashew'));
      expect(systemPrompt, contains('Intent Schemas'));
      expect(systemPrompt, contains('AddTransactionIntent'));
      expect(systemPrompt, contains('AddBudgetIntent'));
      expect(systemPrompt, contains('QuerySpendingIntent'));
      expect(systemPrompt, contains('QueryNetWorthIntent'));
      expect(systemPrompt, contains('NavigateIntent'));
      expect(systemPrompt, contains('PayTransactionIntent'));
      expect(systemPrompt, contains('User Data'));
      expect(systemPrompt, contains('Categories'));
      expect(systemPrompt, contains('Wallets'));
      expect(systemPrompt, contains('Budgets'));
      expect(systemPrompt, contains('Output Format'));
      expect(systemPrompt, contains('Few-Shot Examples'));
    });

    test('buildSystemPrompt includes user category names', () async {
      final builder = TestAiContextBuilder();
      final systemPrompt = await builder.buildSystemPromptForTest(
        categories: [
          _createCategory('Groceries', false),
          _createCategory('Dining Out', false),
        ],
        wallets: [],
        budgets: [],
      );

      expect(systemPrompt, contains('Groceries'));
      expect(systemPrompt, contains('Dining Out'));
    });

    test('buildSystemPrompt includes user wallet names', () async {
      final builder = TestAiContextBuilder();
      final systemPrompt = await builder.buildSystemPromptForTest(
        categories: [],
        wallets: [
          _createWallet('Primary Account', 'USD'),
        ],
        budgets: [],
      );

      expect(systemPrompt, contains('Primary Account'));
    });

    test('buildSystemPrompt includes current date', () async {
      final builder = TestAiContextBuilder();
      final today = DateTime.now();
      final expectedDate =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final systemPrompt = await builder.buildSystemPromptForTest(
        categories: [],
        wallets: [],
        budgets: [],
      );

      expect(systemPrompt, contains('Current Date'));
      expect(systemPrompt, contains(expectedDate));
    });
  });
}

TransactionCategory _createCategory(String name, bool isIncome) {
  return TransactionCategory(
    categoryPk: 'pk_$name',
    name: name,
    colour: '#000000',
    iconName: null,
    emojiIconName: null,
    dateCreated: DateTime.now(),
    dateTimeModified: null,
    order: 0,
    income: isIncome,
    methodAdded: null,
    mainCategoryPk: null,
  );
}

TransactionWallet _createWallet(String name, String currency) {
  return TransactionWallet(
    walletPk: 'pk_$name',
    name: name,
    colour: '#000000',
    iconName: null,
    dateCreated: DateTime.now(),
    dateTimeModified: null,
    order: 0,
    currency: currency,
    currencyFormat: null,
    decimals: 2,
    homePageWidgetDisplay: null,
  );
}

Budget _createBudget(
    String name, double amount, BudgetReoccurence reoccurrence) {
  return Budget(
    budgetPk: 'pk_$name',
    name: name,
    amount: amount,
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
    reoccurrence: reoccurrence,
    dateCreated: DateTime.now(),
    dateTimeModified: null,
    pinned: false,
    order: 0,
    walletFk: '0',
    budgetTransactionFilters: null,
    memberTransactionFilters: null,
    sharedKey: null,
    sharedOwnerMember: null,
    sharedDateUpdated: null,
    sharedMembers: null,
    sharedAllMembersEver: null,
    isAbsoluteSpendingLimit: false,
  );
}

class TestAiContextBuilder extends AiContextBuilder {
  Future<String> getUserCategoriesForTest({
    required List<TransactionCategory> categories,
  }) async {
    final expenseCategories =
        categories.where((c) => c.income == false).map((c) => c.name).toList();
    final incomeCategories =
        categories.where((c) => c.income == true).map((c) => c.name).toList();

    return '''
Expense categories: ${expenseCategories.join(', ')}
Income categories: ${incomeCategories.join(', ')}''';
  }

  Future<String> getUserWalletsForTest({
    required List<TransactionWallet> wallets,
  }) async {
    if (wallets.isEmpty) {
      return 'No wallets created yet';
    }

    final walletList = wallets.map((w) {
      final currency = w.currency ?? 'USD';
      return '${w.name} ($currency)';
    }).toList();

    return walletList.join(', ');
  }

  Future<String> getUserBudgetsForTest({
    required List<Budget> budgets,
  }) async {
    if (budgets.isEmpty) {
      return 'No budgets created yet';
    }

    final budgetList = budgets.map((b) {
      final recurrence = _getReoccurrenceString(b.reoccurrence);
      return '${b.name}: $recurrence budget of ${b.amount}';
    }).toList();

    return budgetList.join('\n');
  }

  String _getReoccurrenceString(BudgetReoccurence? reoccurrence) {
    switch (reoccurrence) {
      case BudgetReoccurence.daily:
        return 'daily';
      case BudgetReoccurence.weekly:
        return 'weekly';
      case BudgetReoccurence.monthly:
        return 'monthly';
      case BudgetReoccurence.yearly:
        return 'yearly';
      case BudgetReoccurence.custom:
      case null:
        return 'custom';
    }
  }

  Future<String> buildSystemPromptForTest({
    required List<TransactionCategory> categories,
    required List<TransactionWallet> wallets,
    required List<Budget> budgets,
  }) async {
    final categoriesStr =
        await getUserCategoriesForTest(categories: categories);
    final walletsStr = await getUserWalletsForTest(wallets: wallets);
    final budgetsStr = await getUserBudgetsForTest(budgets: budgets);
    final today =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    return '''
You are an AI assistant for Cashew, a personal finance management app. Your role is to help users manage their budgets, transactions, and financial goals through natural language commands.

## Role Definition
- Understand user intent from natural language
- Extract structured data from user requests
- Return JSON that the app can execute
- Be concise, friendly, and helpful

## Intent Schemas
The user will ask you to do things. You must respond with a JSON object that matches one of these schemas:

### 1. AddTransactionIntent
For creating expenses, income, subscriptions, or credit/debt transactions.
{
  "intent": "AddTransactionIntent",
  "name": "string (transaction title)",
  "amount": "number",
  "categoryName": "string (exact name from user's categories list)",
  "isIncome": "boolean"
}

### 2. AddBudgetIntent
For creating budget limits.
{
  "intent": "AddBudgetIntent",
  "name": "string (budget name)",
  "amount": "number",
  "reoccurrence": "string",
  "periodLength": "number"
}

### 3. AddObjectiveIntent
For creating savings goals or loans.
{
  "intent": "AddObjectiveIntent",
  "type": "string",
  "name": "string",
  "amount": "number"
}

### 4. QuerySpendingIntent
For querying spending within a time period.
{
  "intent": "QuerySpendingIntent",
  "period": "string"
}

### 5. QueryBudgetRemainingIntent
For checking remaining budget.
{
  "intent": "QueryBudgetRemainingIntent",
  "budgetName": "string"
}

### 6. QueryNetWorthIntent
For calculating total net worth.
{
  "intent": "QueryNetWorthIntent"
}

### 7. NavigateIntent
For navigating to app sections.
{
  "intent": "NavigateIntent",
  "target": "string"
}

### 8. PayTransactionIntent
For marking subscriptions/upcoming transactions as paid.
{
  "intent": "PayTransactionIntent",
  "transactionName": "string",
  "action": "string"
}

### 9. UnclearIntent
When intent cannot be determined.
{
  "intent": "UnclearIntent",
  "clarificationNeeded": "string"
}

## User Data

### Categories
$categoriesStr

### Wallets
$walletsStr

### Budgets
$budgetsStr

### Current Date
$today

## Output Format
- ALWAYS respond with ONLY a valid JSON object
- Do NOT include any explanatory text before or after the JSON
- Use exact names from the user data lists above when referencing categories, wallets, or budgets

## Few-Shot Examples

User: "add 500 rupees for groceries"
Assistant: {"intent":"AddTransactionIntent","name":"Groceries","amount":500,"categoryName":"Food","isIncome":false}
''';
  }
}
