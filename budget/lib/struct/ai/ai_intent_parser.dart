import 'dart:convert';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/ai/ai_intent_types.dart';

class AiIntentParser {
  AiIntent parseResponse(String rawOutput, {String? rawInput}) {
    final input = rawInput ?? rawOutput;

    try {
      final jsonString = _extractJson(rawOutput);
      if (jsonString == null) {
        return UnclearIntent(
          rawInput: input,
          clarificationNeeded:
              'I could not understand your request. Could you rephrase it?',
        );
      }

      final Map<String, dynamic> json = jsonDecode(jsonString);
      final intentType = json['intent'] as String?;

      if (intentType == null) {
        return UnclearIntent(
          rawInput: input,
          clarificationNeeded:
              'I could not understand your request. Could you rephrase it?',
        );
      }

      switch (intentType) {
        case 'AddTransactionIntent':
          return _parseAddTransactionIntent(json, input);
        case 'AddBudgetIntent':
          return _parseAddBudgetIntent(json, input);
        case 'AddObjectiveIntent':
          return _parseAddObjectiveIntent(json, input);
        case 'QuerySpendingIntent':
          return _parseQuerySpendingIntent(json, input);
        case 'QueryBudgetRemainingIntent':
          return _parseQueryBudgetRemainingIntent(json, input);
        case 'QueryNetWorthIntent':
          return QueryNetWorthIntent(rawInput: input);
        case 'NavigateIntent':
          return _parseNavigateIntent(json, input);
        case 'PayTransactionIntent':
          return _parsePayTransactionIntent(json, input);
        default:
          return UnclearIntent(
            rawInput: input,
            clarificationNeeded:
                'I did not understand the requested action. Could you rephrase?',
          );
      }
    } catch (e) {
      return UnclearIntent(
        rawInput: input,
        clarificationNeeded:
            'I encountered an error processing your request. Could you try again?',
      );
    }
  }

  String? _extractJson(String text) {
    text = text.trim();

    int startIndex = -1;
    int braceCount = 0;

    for (int i = 0; i < text.length; i++) {
      if (text[i] == '{') {
        if (startIndex == -1) {
          startIndex = i;
        }
        braceCount++;
      } else if (text[i] == '}') {
        braceCount--;
        if (braceCount == 0 && startIndex != -1) {
          return text.substring(startIndex, i + 1);
        }
      }
    }

    final jsonRegex = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}');
    final match = jsonRegex.firstMatch(text);
    if (match != null) {
      try {
        jsonDecode(match.group(0)!);
        return match.group(0);
      } catch (_) {}
    }

    return null;
  }

  AddTransactionIntent _parseAddTransactionIntent(
      Map<String, dynamic> json, String rawInput) {
    return AddTransactionIntent(
      rawInput: rawInput,
      name: json['name'] as String?,
      amount: _parseDouble(json['amount']),
      categoryName: json['categoryName'] as String?,
      isIncome: json['isIncome'] as bool? ?? false,
      type: _parseTransactionSpecialType(json['type'] as String?),
      reoccurrence: _parseBudgetReoccurence(json['reoccurrence'] as String?),
      periodLength: json['periodLength'] as int?,
      date: json['date'] as String?,
      walletName: json['walletName'] as String?,
      note: json['note'] as String?,
    );
  }

  AddBudgetIntent _parseAddBudgetIntent(
      Map<String, dynamic> json, String rawInput) {
    return AddBudgetIntent(
      rawInput: rawInput,
      name: json['name'] as String?,
      amount: _parseDouble(json['amount']),
      reoccurrence: _parseBudgetReoccurence(json['reoccurrence'] as String?) ??
          BudgetReoccurence.monthly,
      periodLength: json['periodLength'] as int? ?? 1,
      categoryNames: _parseStringList(json['categoryNames']),
      walletName: json['walletName'] as String?,
    );
  }

  AddObjectiveIntent _parseAddObjectiveIntent(
      Map<String, dynamic> json, String rawInput) {
    return AddObjectiveIntent(
      rawInput: rawInput,
      type: _parseObjectiveType(json['type'] as String?),
      name: json['name'] as String?,
      amount: _parseDouble(json['amount']),
      isIncome: json['isIncome'] as bool? ?? false,
      endDate: json['endDate'] as String?,
    );
  }

  QuerySpendingIntent _parseQuerySpendingIntent(
      Map<String, dynamic> json, String rawInput) {
    return QuerySpendingIntent(
      rawInput: rawInput,
      period: json['period'] as String?,
      categoryName: json['categoryName'] as String?,
      budgetName: json['budgetName'] as String?,
      isIncome: json['isIncome'] as bool?,
    );
  }

  QueryBudgetRemainingIntent _parseQueryBudgetRemainingIntent(
      Map<String, dynamic> json, String rawInput) {
    return QueryBudgetRemainingIntent(
      rawInput: rawInput,
      budgetName: json['budgetName'] as String?,
    );
  }

  NavigateIntent _parseNavigateIntent(
      Map<String, dynamic> json, String rawInput) {
    final target = json['target'] as String? ?? 'home';
    return NavigateIntent(
      rawInput: rawInput,
      target: _normalizeNavigationTarget(target),
    );
  }

  PayTransactionIntent _parsePayTransactionIntent(
      Map<String, dynamic> json, String rawInput) {
    return PayTransactionIntent(
      rawInput: rawInput,
      transactionName: json['transactionName'] as String?,
      action: json['action'] as String?,
    );
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  TransactionSpecialType? _parseTransactionSpecialType(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'upcoming':
        return TransactionSpecialType.upcoming;
      case 'subscription':
        return TransactionSpecialType.subscription;
      case 'repetitive':
        return TransactionSpecialType.repetitive;
      case 'credit':
        return TransactionSpecialType.credit;
      case 'debt':
        return TransactionSpecialType.debt;
      default:
        return null;
    }
  }

  BudgetReoccurence? _parseBudgetReoccurence(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'daily':
        return BudgetReoccurence.daily;
      case 'weekly':
        return BudgetReoccurence.weekly;
      case 'monthly':
        return BudgetReoccurence.monthly;
      case 'yearly':
        return BudgetReoccurence.yearly;
      case 'custom':
        return BudgetReoccurence.custom;
      default:
        return null;
    }
  }

  ObjectiveType _parseObjectiveType(String? value) {
    if (value == null) return ObjectiveType.goal;
    switch (value.toLowerCase()) {
      case 'loan':
        return ObjectiveType.loan;
      case 'goal':
      default:
        return ObjectiveType.goal;
    }
  }

  String _normalizeNavigationTarget(String target) {
    final normalized = target.toLowerCase().trim();

    final targetMappings = [
      ('budgets', ['budgets', 'budget', 'spending limits', 'spending limit']),
      ('subscriptions', ['subscriptions', 'subscription', 'recurring']),
      ('goals', ['goals', 'goal', 'objectives', 'savings goals', 'savings']),
      ('transactions', ['transactions', 'transaction', 'history', 'records']),
      ('wallets', ['wallets', 'wallet', 'accounts', 'account']),
      ('categories', ['categories', 'category']),
      ('settings', ['settings', 'preferences', 'config']),
      ('home', ['home', 'dashboard', 'main']),
    ];

    for (final (key, keywords) in targetMappings) {
      if (keywords.any((v) => normalized.contains(v))) {
        return key;
      }
    }

    return 'home';
  }
}
