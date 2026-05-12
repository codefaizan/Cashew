import 'package:budget/database/tables.dart';
import 'package:budget/struct/ai/ai_intent_types.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/navigationFramework.dart';

class AiIntentExecutor {
  Future<AiExecutionResult> execute(AiIntent intent) async {
    return switch (intent) {
      AddTransactionIntent intent => await executeAddTransaction(intent),
      AddBudgetIntent intent => await executeAddBudget(intent),
      AddObjectiveIntent intent => await executeAddObjective(intent),
      QuerySpendingIntent intent => await executeQuerySpending(intent),
      QueryBudgetRemainingIntent intent =>
        await executeQueryBudgetRemaining(intent),
      QueryNetWorthIntent intent => await executeQueryNetWorth(intent),
      NavigateIntent intent => await executeNavigate(intent),
      PayTransactionIntent intent => await executePayTransaction(intent),
      UnclearIntent intent => executeUnclear(intent),
    };
  }

  Future<String?> resolveCategoryFk(String? categoryName) async {
    if (categoryName == null || categoryName.isEmpty) return null;

    final categories = await database.getAllCategories();
    final lowerName = categoryName.toLowerCase();

    for (final category in categories) {
      if (category.name.toLowerCase() == lowerName) {
        return category.categoryPk;
      }
    }

    for (final category in categories) {
      if (category.name.toLowerCase().contains(lowerName) ||
          lowerName.contains(category.name.toLowerCase())) {
        return category.categoryPk;
      }
    }

    final associatedTitles = await database.getSimilarAssociatedTitles(
      title: categoryName,
      alsoSearchCategories: true,
    );
    if (associatedTitles.isNotEmpty) {
      return associatedTitles.first.category.categoryPk;
    }

    return null;
  }

  Future<String> resolveWalletFk(String? walletName) async {
    final wallets = await database.getAllWallets();
    final defaultWallet = appStateSettings["selectedWalletPk"] ?? "0";

    if (walletName == null || walletName.isEmpty) {
      return defaultWallet;
    }

    final lowerName = walletName.toLowerCase();

    for (final wallet in wallets) {
      if (wallet.name.toLowerCase() == lowerName) {
        return wallet.walletPk;
      }
    }

    for (final wallet in wallets) {
      if (wallet.name.toLowerCase().contains(lowerName) ||
          lowerName.contains(wallet.name.toLowerCase())) {
        return wallet.walletPk;
      }
    }

    return defaultWallet;
  }

  Future<String?> resolveBudgetFk(String? budgetName) async {
    if (budgetName == null || budgetName.isEmpty) return null;

    final budgets = await database.getAllBudgets();
    final lowerName = budgetName.toLowerCase();

    for (final budget in budgets) {
      if (budget.name.toLowerCase() == lowerName) {
        return budget.budgetPk;
      }
    }

    for (final budget in budgets) {
      if (budget.name.toLowerCase().contains(lowerName) ||
          lowerName.contains(budget.name.toLowerCase())) {
        return budget.budgetPk;
      }
    }

    return null;
  }

  (DateTime, DateTime)? resolveTimePeriod(String? period) {
    if (period == null || period.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lowerPeriod = period.toLowerCase().trim();
    print('=== RESOLVE PERIOD === input: "$period", lower: "$lowerPeriod"');

    if (lowerPeriod == 'today') {
      final startOfDay = today;
      final endOfDay = today
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      print('=== RESOLVE PERIOD === returning today: $startOfDay to $endOfDay');
      return (startOfDay, endOfDay);
    }

    if (lowerPeriod == 'yesterday') {
      final startOfDay = today.subtract(const Duration(days: 1));
      final endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      return (startOfDay, endOfDay);
    }

    if (lowerPeriod == 'this week' || lowerPeriod == 'week') {
      final weekday = now.weekday;
      final startOfWeek = today.subtract(Duration(days: weekday - 1));
      final endOfDay = today
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      return (startOfWeek, endOfDay);
    }

    if (lowerPeriod == 'this month' || lowerPeriod == 'month') {
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfDay = today
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      return (startOfMonth, endOfDay);
    }

    if (lowerPeriod == 'this year' || lowerPeriod == 'year') {
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfDay = today
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      return (startOfYear, endOfDay);
    }

    return null;
  }

  Future<AiExecutionResult> executeAddTransaction(
      AddTransactionIntent intent) async {
    try {
      final categoryFk = await resolveCategoryFk(intent.categoryName);
      if (categoryFk == null) {
        return AiExecutionResult(
          success: false,
          message:
              'Category "${intent.categoryName ?? 'unknown'}" not found. Should I create it?',
          actionType: 'create_category',
        );
      }

      final walletFk = await resolveWalletFk(intent.walletName);

      final category = await database.getCategoryInstance(categoryFk);
      final amount = intent.isIncome
          ? (intent.amount ?? 0).abs()
          : -(intent.amount ?? 0).abs();

      DateTime dateCreated;
      if (intent.date != null && intent.date!.isNotEmpty) {
        try {
          dateCreated = DateTime.parse(intent.date!);
        } catch (_) {
          dateCreated = DateTime.now();
        }
      } else {
        dateCreated = DateTime.now();
      }

      final type = intent.type;
      final reoccurrence = intent.reoccurrence;

      final transaction = Transaction(
        transactionPk: "-1",
        name: intent.name ?? 'Transaction',
        amount: amount,
        note: intent.note ?? '',
        categoryFk: categoryFk,
        subCategoryFk: null,
        walletFk: walletFk,
        dateCreated: dateCreated,
        endDate: null,
        dateTimeModified: null,
        income: intent.isIncome,
        paid: type == TransactionSpecialType.credit ||
            type == TransactionSpecialType.debt,
        skipPaid: false,
        type: type,
        reoccurrence: reoccurrence,
        periodLength: intent.periodLength,
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

      final rowId = await database.createOrUpdateTransaction(
        transaction,
        insert: true,
      );

      if (intent.name != null && intent.name!.isNotEmpty) {
        await addAssociatedTitles(intent.name!, categoryFk);
      }

      return AiExecutionResult(
        success: true,
        message: intent.isIncome
            ? 'Added ₹${intent.amount?.toStringAsFixed(0)} income to ${category.name}'
            : 'Added ₹${intent.amount?.abs().toStringAsFixed(0)} expense to ${category.name}',
        actionType: 'transaction_created',
        detailRoute: 'transaction:$rowId',
        createdObject: transaction,
      );
    } catch (e) {
      return AiExecutionResult(
        success: false,
        message: 'Failed to create transaction: ${e.toString()}',
      );
    }
  }

  Future<AiExecutionResult> executeAddBudget(AddBudgetIntent intent) async {
    try {
      final walletFk = await resolveWalletFk(intent.walletName);

      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      switch (intent.reoccurrence) {
        case BudgetReoccurence.daily:
          startDate = DateTime(now.year, now.month, now.day);
          endDate = startDate.add(Duration(days: intent.periodLength));
          break;
        case BudgetReoccurence.weekly:
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = startDate.add(Duration(days: 7 * intent.periodLength));
          break;
        case BudgetReoccurence.monthly:
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + intent.periodLength, 1);
          break;
        case BudgetReoccurence.yearly:
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year + intent.periodLength, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 1);
      }

      List<String>? categoryFks;
      if (intent.categoryNames != null && intent.categoryNames!.isNotEmpty) {
        categoryFks = [];
        for (final categoryName in intent.categoryNames!) {
          final categoryFk = await resolveCategoryFk(categoryName);
          if (categoryFk != null) {
            categoryFks.add(categoryFk);
          }
        }
      }

      final budgets = await database.getAllBudgets();
      final order = budgets.length;

      final budget = Budget(
        budgetPk: "-1",
        name: intent.name ?? 'Budget',
        amount: intent.amount ?? 0,
        colour: null,
        startDate: startDate,
        endDate: endDate,
        walletFks: null,
        categoryFks: categoryFks,
        categoryFksExclude: null,
        income: false,
        archived: false,
        addedTransactionsOnly: false,
        periodLength: intent.periodLength,
        reoccurrence: intent.reoccurrence,
        dateCreated: DateTime.now(),
        dateTimeModified: null,
        pinned: false,
        order: order,
        walletFk: walletFk,
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

      await database.createOrUpdateBudget(budget, insert: true);

      final recurrenceStr = _getReoccurrenceString(intent.reoccurrence);

      return AiExecutionResult(
        success: true,
        message:
            'Created budget "${intent.name}" with ₹${intent.amount?.toStringAsFixed(0)} $recurrenceStr limit',
        actionType: 'budget_created',
        detailRoute: 'budget:${intent.name}',
        createdObject: budget,
      );
    } catch (e) {
      return AiExecutionResult(
        success: false,
        message: 'Failed to create budget: ${e.toString()}',
      );
    }
  }

  Future<AiExecutionResult> executeAddObjective(
      AddObjectiveIntent intent) async {
    try {
      final walletFk = await resolveWalletFk(null);

      DateTime? endDate;
      if (intent.endDate != null && intent.endDate!.isNotEmpty) {
        try {
          endDate = DateTime.parse(intent.endDate!);
        } catch (_) {
          endDate = null;
        }
      }

      final objectives = await database.getAllObjectives(
        objectiveType: intent.type,
      );
      final order = objectives.length;

      final objective = Objective(
        objectivePk: "-1",
        type: intent.type,
        name: intent.name ?? 'Goal',
        amount: intent.amount ?? 0,
        order: order,
        colour: null,
        dateCreated: DateTime.now(),
        endDate: endDate,
        dateTimeModified: null,
        iconName: null,
        emojiIconName: null,
        income: intent.isIncome,
        pinned: true,
        archived: false,
        walletFk: walletFk,
      );

      await database.createOrUpdateObjective(objective, insert: true);

      if (intent.type == ObjectiveType.loan && !intent.isIncome) {
        final transaction = Transaction(
          transactionPk: "-1",
          name: 'Loan to ${intent.name}',
          amount: -(intent.amount ?? 0),
          note: 'Initial loan transaction',
          categoryFk: '0',
          subCategoryFk: null,
          walletFk: walletFk,
          dateCreated: DateTime.now(),
          endDate: null,
          dateTimeModified: null,
          income: false,
          paid: false,
          skipPaid: false,
          type: TransactionSpecialType.credit,
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
          objectiveLoanFk: objective.objectivePk,
          budgetFksExclude: null,
          pairedTransactionFk: null,
        );
        await database.createOrUpdateTransaction(transaction, insert: true);
      }

      final typeStr = intent.type == ObjectiveType.goal ? 'goal' : 'loan';
      return AiExecutionResult(
        success: true,
        message: intent.type == ObjectiveType.goal
            ? 'Created goal "${intent.name}" — save ₹${intent.amount?.toStringAsFixed(0)}'
            : 'Created loan "${intent.name}" for ₹${intent.amount?.toStringAsFixed(0)}',
        actionType: '${typeStr}_created',
        detailRoute: '${typeStr}:${intent.name}',
        createdObject: objective,
      );
    } catch (e) {
      return AiExecutionResult(
        success: false,
        message: 'Failed to create objective: ${e.toString()}',
      );
    }
  }

  Future<AiExecutionResult> executeQuerySpending(
      QuerySpendingIntent intent) async {
    try {
      DateTime startDate;
      DateTime endDate;

      if (intent.period != null) {
        final period = resolveTimePeriod(intent.period);
        if (period != null) {
          startDate = period.$1;
          endDate = period.$2;
        } else {
          startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
          endDate = DateTime.now();
        }
      } else {
        startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
        endDate = DateTime.now();
      }

      List<String>? categoryFks;
      if (intent.categoryName != null) {
        final categoryFk = await resolveCategoryFk(intent.categoryName);
        if (categoryFk != null) {
          categoryFks = [categoryFk];
        }
      }

      print('=== QUERY SPENDING === intent.period: ${intent.period}');

      final transactions = await database
          .getTransactionCategoryWithDay(
            startDate,
            endDate,
            categoryFks: categoryFks,
            budgetTransactionFilters: [
              BudgetTransactionFilters.defaultBudgetTransactionFilters
            ],
            memberTransactionFilters: null,
          )
          .first;

      print(
          '=== QUERY SPENDING === start: $startDate, end: $endDate, found: ${transactions.length}');

      double total = 0;
      int count = 0;
      final Map<String, double> byCategory = {};

      for (final twc in transactions) {
        final amount = twc.transaction.amount;
        if (intent.isIncome == true && !twc.transaction.income) continue;
        if (intent.isIncome == false && twc.transaction.income) continue;

        total += amount.abs();
        count++;

        final categoryName = twc.category.name;
        byCategory[categoryName] =
            (byCategory[categoryName] ?? 0) + amount.abs();
      }

      final sortedCategories = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topCategories = sortedCategories.take(3).map((e) {
        return '${e.key} ₹${e.value.toStringAsFixed(0)}';
      }).join(', ');

      String periodStr = intent.period ?? 'this month';
      print('=== MESSAGE BEFORE === periodStr before: $periodStr');
      if (periodStr.toLowerCase() == 'this month' ||
          periodStr.toLowerCase() == 'month') {
        periodStr = 'month';
      } else if (periodStr.toLowerCase() == 'this week' ||
          periodStr.toLowerCase() == 'week') {
        periodStr = 'week';
      } else if (periodStr.toLowerCase() == 'today' ||
          periodStr.toLowerCase() == 'day') {
        periodStr = 'today';
      } else if (periodStr.toLowerCase() == 'yesterday') {
        periodStr = 'yesterday';
      } else if (periodStr.toLowerCase() == 'this year' ||
          periodStr.toLowerCase() == 'year') {
        periodStr = 'year';
      }
      print('=== MESSAGE AFTER === periodStr after: $periodStr');

      return AiExecutionResult(
        success: true,
        message:
            'You spent ₹${total.toStringAsFixed(0)} this $periodStr across $count transactions.${topCategories.isNotEmpty ? ' Top: $topCategories' : ''}',
        actionType: 'spending_query',
        createdObject: {
          'total': total,
          'count': count,
          'byCategory': byCategory,
          'startDate': startDate,
          'endDate': endDate,
          'period': periodStr,
        },
      );
    } catch (e) {
      return AiExecutionResult(
        success: false,
        message: 'Failed to query spending: ${e.toString()}',
      );
    }
  }

  Future<AiExecutionResult> executeQueryBudgetRemaining(
      QueryBudgetRemainingIntent intent) async {
    try {
      final budgetPk = await resolveBudgetFk(intent.budgetName);
      if (budgetPk == null) {
        return AiExecutionResult(
          success: false,
          message: 'Budget "${intent.budgetName ?? 'unknown'}" not found',
        );
      }

      final budget = await database.getBudgetInstance(budgetPk);

      final transactions = await database
          .getTransactionCategoryWithDay(
            budget.startDate,
            budget.endDate,
            categoryFks: budget.categoryFks,
            walletFks: budget.walletFks ?? [],
            budgetTransactionFilters: budget.budgetTransactionFilters,
            memberTransactionFilters: budget.memberTransactionFilters,
          )
          .first;

      double spent = 0;
      for (final twc in transactions) {
        if (!twc.transaction.income) {
          spent += twc.transaction.amount.abs();
        }
      }

      final remaining = budget.amount - spent;
      final percentUsed = budget.amount > 0 ? (spent / budget.amount * 100) : 0;

      return AiExecutionResult(
        success: true,
        message:
            'Budget "${budget.name}" has ₹${remaining.toStringAsFixed(0)} remaining of ₹${budget.amount.toStringAsFixed(0)} (${percentUsed.toStringAsFixed(0)}% used)',
        actionType: 'budget_remaining_query',
        createdObject: {
          'budget': budget,
          'spent': spent,
          'remaining': remaining,
          'percentUsed': percentUsed,
        },
      );
    } catch (e) {
      return AiExecutionResult(
        success: false,
        message: 'Failed to query budget: ${e.toString()}',
      );
    }
  }

  Future<AiExecutionResult> executeQueryNetWorth(
      QueryNetWorthIntent intent) async {
    try {
      final allWallets = await database.getAllWallets();
      if (allWallets.isEmpty) {
        return AiExecutionResult(
          success: true,
          message: 'No wallets found. Add a wallet first.',
          actionType: 'net_worth_query',
          createdObject: {'total': 0.0, 'walletCount': 0},
        );
      }

      final allWalletsObj = AllWallets(
        list: allWallets,
        indexedByPk: {for (final w in allWallets) w.walletPk: w},
      );

      double total = 0;
      for (final _ in allWallets) {
        final stream = database.watchTotalWithCountOfWallet(
          isIncome: null,
          allWallets: allWalletsObj,
          followCustomPeriodCycle: false,
          includeBalanceCorrection: true,
          onlyIncomeAndExpense: false,
        );
        final result = await stream.first;
        total += result?.total ?? 0;
      }

      return AiExecutionResult(
        success: true,
        message:
            'Your net worth is ₹${total.toStringAsFixed(0)} across ${allWallets.length} accounts',
        actionType: 'net_worth_query',
        createdObject: {
          'total': total,
          'walletCount': allWallets.length,
        },
      );
    } catch (e) {
      return AiExecutionResult(
        success: false,
        message: 'Failed to calculate net worth: ${e.toString()}',
      );
    }
  }

  Future<AiExecutionResult> executeNavigate(NavigateIntent intent) async {
    final target = intent.target.toLowerCase();

    int pageIndex;
    switch (target) {
      case 'home':
        pageIndex = 0;
        break;
      case 'transactions':
        pageIndex = 1;
        break;
      case 'budgets':
        pageIndex = 2;
        break;
      case 'subscriptions':
        pageIndex = 5;
        break;
      case 'goals':
        pageIndex = 14;
        break;
      case 'settings':
        pageIndex = 3;
        break;
      case 'wallets':
      case 'accounts':
        pageIndex = 8;
        break;
      case 'categories':
        pageIndex = 11;
        break;
      default:
        return AiExecutionResult(
          success: false,
          message: 'Could not navigate to "$target"',
        );
    }

    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        PageNavigationFramework.changePage(context, pageIndex);
      }

      return AiExecutionResult(
        success: true,
        message: 'Opening ${_capitalizeFirst(target)}...',
        actionType: 'navigation',
        detailRoute: target,
      );
    } catch (e) {
      return AiExecutionResult(
        success: false,
        message: 'Failed to navigate: ${e.toString()}',
      );
    }
  }

  Future<AiExecutionResult> executePayTransaction(
      PayTransactionIntent intent) async {
    try {
      final transactionName = intent.transactionName ?? '';
      final action = intent.action?.toLowerCase() ?? 'pay';

      final (_, subscriptionsFuture) = database.getAllSubscriptions();
      final subscriptions = await subscriptionsFuture;
      final upcoming = await database.getAllUpcomingTransactions();

      Transaction? foundTransaction;

      for (final sub in subscriptions) {
        if (sub.name.toLowerCase().contains(transactionName.toLowerCase())) {
          foundTransaction = sub;
          break;
        }
      }

      if (foundTransaction == null) {
        for (final up in upcoming) {
          if (up.name.toLowerCase().contains(transactionName.toLowerCase())) {
            foundTransaction = up;
            break;
          }
        }
      }

      if (foundTransaction == null) {
        return AiExecutionResult(
          success: false,
          message:
              'Could not find subscription or upcoming transaction named "$transactionName"',
        );
      }

      if (action == 'skip') {
        final updated = foundTransaction.copyWith(skipPaid: true);
        await database.createOrUpdateTransaction(updated);
        return AiExecutionResult(
          success: true,
          message: 'Skipped "${foundTransaction.name}"',
          actionType: 'transaction_skipped',
        );
      } else {
        final updated = foundTransaction.copyWith(paid: true);
        await database.createOrUpdateTransaction(updated);
        return AiExecutionResult(
          success: true,
          message: 'Marked "${foundTransaction.name}" as paid',
          actionType: 'transaction_paid',
        );
      }
    } catch (e) {
      return AiExecutionResult(
        success: false,
        message: 'Failed to pay transaction: ${e.toString()}',
      );
    }
  }

  AiExecutionResult executeUnclear(UnclearIntent intent) {
    return AiExecutionResult(
      success: false,
      message: intent.clarificationNeeded ??
          "I didn't understand that. Could you rephrase?",
      actionType: 'unclear',
    );
  }

  Future<void> addAssociatedTitles(String title, String categoryFk) async {
    final existingTitles =
        await database.getAllAssociatedTitlesInCategory(categoryFk);
    final existingTitleNames =
        existingTitles.map((t) => t.title.toLowerCase()).toSet();

    final words = title.split(' ').where((w) => w.length > 2).toList();

    for (final word in words) {
      if (!existingTitleNames.contains(word.toLowerCase())) {
        final maxOrder = existingTitles.isEmpty
            ? 0
            : existingTitles
                .map((t) => t.order)
                .reduce((a, b) => a > b ? a : b);

        final associatedTitle = TransactionAssociatedTitle(
          associatedTitlePk: "-1",
          categoryFk: categoryFk,
          title: word,
          dateCreated: DateTime.now(),
          dateTimeModified: null,
          order: maxOrder + 1,
          isExactMatch: false,
        );

        await database.createOrUpdateAssociatedTitle(associatedTitle,
            insert: true);
      }
    }

    if (!existingTitleNames.contains(title.toLowerCase())) {
      final maxOrder = existingTitles.isEmpty
          ? 0
          : existingTitles.map((t) => t.order).reduce((a, b) => a > b ? a : b);

      final associatedTitle = TransactionAssociatedTitle(
        associatedTitlePk: "-1",
        categoryFk: categoryFk,
        title: title,
        dateCreated: DateTime.now(),
        dateTimeModified: null,
        order: maxOrder + 1,
        isExactMatch: true,
      );

      await database.createOrUpdateAssociatedTitle(associatedTitle,
          insert: true);
    }
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

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
