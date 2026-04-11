import 'package:budget/database/tables.dart';

sealed class AiIntent {
  final String rawInput;
  AiIntent({required this.rawInput});
}

class AddTransactionIntent extends AiIntent {
  String? name;
  double? amount;
  String? categoryName;
  bool isIncome;
  TransactionSpecialType? type;
  BudgetReoccurence? reoccurrence;
  int? periodLength;
  String? date;
  String? walletName;
  String? note;

  AddTransactionIntent({
    required super.rawInput,
    this.name,
    this.amount,
    this.categoryName,
    this.isIncome = false,
    this.type,
    this.reoccurrence,
    this.periodLength,
    this.date,
    this.walletName,
    this.note,
  });
}

class AddBudgetIntent extends AiIntent {
  String? name;
  double? amount;
  BudgetReoccurence reoccurrence;
  int periodLength;
  List<String>? categoryNames;
  String? walletName;

  AddBudgetIntent({
    required super.rawInput,
    this.name,
    this.amount,
    this.reoccurrence = BudgetReoccurence.monthly,
    this.periodLength = 1,
    this.categoryNames,
    this.walletName,
  });
}

class AddObjectiveIntent extends AiIntent {
  ObjectiveType type;
  String? name;
  double? amount;
  bool isIncome;
  String? endDate;

  AddObjectiveIntent({
    required super.rawInput,
    this.type = ObjectiveType.goal,
    this.name,
    this.amount,
    this.isIncome = false,
    this.endDate,
  });
}

class QuerySpendingIntent extends AiIntent {
  String? period;
  String? categoryName;
  String? budgetName;
  bool? isIncome;

  QuerySpendingIntent({
    required super.rawInput,
    this.period,
    this.categoryName,
    this.budgetName,
    this.isIncome,
  });
}

class QueryBudgetRemainingIntent extends AiIntent {
  String? budgetName;

  QueryBudgetRemainingIntent({
    required super.rawInput,
    this.budgetName,
  });
}

class QueryNetWorthIntent extends AiIntent {
  QueryNetWorthIntent({required super.rawInput});
}

class NavigateIntent extends AiIntent {
  String target;

  NavigateIntent({
    required super.rawInput,
    required this.target,
  });
}

class PayTransactionIntent extends AiIntent {
  String? transactionName;
  String? action;

  PayTransactionIntent({
    required super.rawInput,
    this.transactionName,
    this.action,
  });
}

class UnclearIntent extends AiIntent {
  String? clarificationNeeded;

  UnclearIntent({
    required super.rawInput,
    this.clarificationNeeded,
  });
}

class AiExecutionResult {
  final bool success;
  final String? message;
  final String? actionType;
  final String? detailRoute;
  final dynamic createdObject;

  AiExecutionResult({
    required this.success,
    this.message,
    this.actionType,
    this.detailRoute,
    this.createdObject,
  });
}
