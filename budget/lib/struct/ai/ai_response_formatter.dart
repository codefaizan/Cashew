import 'package:budget/struct/ai/ai_intent_types.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';

class AiActionButton {
  final String label;
  final String route;

  AiActionButton({required this.label, required this.route});
}

class AiResponseFormatter {
  final AllWallets? allWallets;

  AiResponseFormatter({this.allWallets});

  String _formatAmount(double amount) {
    if (allWallets != null) {
      return convertToMoney(allWallets!, amount.abs());
    }
    return '₹${amount.abs().toStringAsFixed(0)}';
  }

  String format(AiExecutionResult result) {
    final actionType = result.actionType;
    final createdObject = result.createdObject;

    // Use the executor's message if available
    if (result.message != null &&
        actionType != 'spending_query' &&
        actionType != 'budget_remaining_query' &&
        actionType != 'net_worth_query') {
      return result.message!;
    }

    switch (actionType) {
      case 'transaction_created':
        if (createdObject is Transaction) {
          final isIncome = createdObject.income;
          final amount = _formatAmount(createdObject.amount);
          final name = createdObject.name;
          return 'Added $amount ${isIncome ? 'income' : 'expense'} to $name';
        }
        break;

      case 'budget_created':
        if (createdObject is Budget) {
          final amount = _formatAmount(createdObject.amount);
          final name = createdObject.name;
          final recurrenceStr = _getReoccurrenceString(
              createdObject.reoccurrence ?? BudgetReoccurence.monthly);
          return "Created budget '$name' with $amount $recurrenceStr limit";
        }
        break;

      case 'goal_created':
        if (createdObject is Objective) {
          final amount = _formatAmount(createdObject.amount);
          final name = createdObject.name;
          return "Created goal '$name' — save $amount";
        }
        break;

      case 'loan_created':
        if (createdObject is Objective) {
          final amount = _formatAmount(createdObject.amount);
          final name = createdObject.name;
          return "Created loan '$name' for $amount";
        }
        break;

      case 'spending_query':
        if (createdObject is Map) {
          final total = _formatAmount(createdObject['total'] as double);
          final count = createdObject['count'] as int;
          final byCategory = createdObject['byCategory'] as Map<String, double>;

          final sortedCategories = byCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topCategories = sortedCategories.take(3).map((e) {
            return '${e.key} ${_formatAmount(e.value)}';
          }).join(', ');

          String message =
              'You spent $total this month across $count transactions';
          if (topCategories.isNotEmpty) {
            message += '. Top: $topCategories';
          }
          return message;
        }
        break;

      case 'budget_remaining_query':
        if (createdObject is Map) {
          final remaining = _formatAmount(createdObject['remaining'] as double);
          final total = _formatAmount((createdObject['spent'] as double) +
              (createdObject['remaining'] as double));
          final percentUsed =
              (createdObject['percentUsed'] as double).toStringAsFixed(0);
          final budget = createdObject['budget'] as Budget;
          return "Budget '${budget.name}' has $remaining remaining of $total ($percentUsed% used)";
        }
        break;

      case 'net_worth_query':
        if (createdObject is Map) {
          final total = _formatAmount(createdObject['total'] as double);
          final walletCount = createdObject['walletCount'] as int;
          return 'Your net worth is $total across $walletCount accounts';
        }
        break;

      case 'navigation':
        final target = result.detailRoute ?? 'page';
        return 'Opening ${_capitalizeFirst(target)}...';

      case 'transaction_paid':
        final detailRoute = result.detailRoute;
        if (detailRoute != null) {
          final name = detailRoute.split(':').last;
          return 'Marked "$name" as paid';
        }
        return 'Marked subscription as paid';

      case 'transaction_skipped':
        final detailRoute = result.detailRoute;
        if (detailRoute != null) {
          final name = detailRoute.split(':').last;
          return 'Skipped "$name"';
        }
        return 'Skipped subscription';

      case 'create_category':
        return result.message ?? 'Should I create that category?';
    }

    if (!result.success) {
      return result.message ?? 'Something went wrong. Please try again.';
    }

    return result.message ?? "Action completed";
  }

  String _getReoccurrenceString(BudgetReoccurence reoccurrence) {
    return switch (reoccurrence) {
      BudgetReoccurence.daily => 'daily',
      BudgetReoccurence.weekly => 'weekly',
      BudgetReoccurence.monthly => 'monthly',
      BudgetReoccurence.yearly => 'yearly',
      _ => 'monthly',
    };
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  AiActionButton? getViewAction(AiExecutionResult result) {
    final actionType = result.actionType;
    final detailRoute = result.detailRoute;

    switch (actionType) {
      case 'transaction_created':
        if (detailRoute == null) return null;
        return AiActionButton(label: 'View Transaction', route: detailRoute);
      case 'budget_created':
        if (detailRoute == null) return null;
        return AiActionButton(label: 'View Budget', route: detailRoute);
      case 'goal_created':
        if (detailRoute == null) return null;
        return AiActionButton(label: 'View Goal', route: detailRoute);
      case 'loan_created':
        if (detailRoute == null) return null;
        return AiActionButton(label: 'View Loan', route: detailRoute);
      case 'spending_query':
        return AiActionButton(
            label: 'View Transactions', route: '/transactions');
      case 'budget_remaining_query':
        if (detailRoute == null) return null;
        return AiActionButton(label: 'View Budget', route: detailRoute);
      case 'net_worth_query':
        return AiActionButton(label: 'View Accounts', route: '/wallets');
      default:
        return null;
    }
  }
}
