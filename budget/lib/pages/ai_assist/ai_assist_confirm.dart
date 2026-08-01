import 'package:budget/database/tables.dart';
import 'package:budget/pages/ai_assist/ai_assist_models.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';

class ConfirmResult {
  final String transactionPk;
  final String? newCategoryPk;
  final String? newCategoryName;

  const ConfirmResult({
    required this.transactionPk,
    this.newCategoryPk,
    this.newCategoryName,
  });
}

class AiAssistConfirmHandler {
  const AiAssistConfirmHandler();

  Future<String?> _resolveCategoryPk(TransactionDraft draft) async {
    if (draft.createNewCategory) {
      return null;
    }

    if (draft.categoryName == null || draft.categoryName!.trim().isEmpty) {
      return null;
    }

    final catName = draft.categoryName!.trim().toLowerCase();
    final categories = await database.getAllCategories();
    for (final cat in categories) {
      if (cat.name.trim().toLowerCase() == catName &&
          cat.income == draft.income) {
        return cat.categoryPk;
      }
    }
    return null;
  }

  Future<String?> _ensureCategory(TransactionDraft draft, bool income) async {
    if (draft.createNewCategory &&
        draft.newCategoryName != null &&
        draft.newCategoryName!.trim().isNotEmpty) {
      final newPk = uuid.v4();
      final order = await database.getAmountOfCategories();
      final category = TransactionCategory(
        categoryPk: newPk,
        name: draft.newCategoryName!.trim(),
        colour: null,
        iconName: income ? "savings.png" : "image.png",
        emojiIconName: null,
        dateCreated: DateTime.now(),
        dateTimeModified: null,
        order: order,
        income: income,
        methodAdded: null,
        mainCategoryPk: null,
      );
      await database.createOrUpdateCategory(category, insert: false);
      return newPk;
    }

    return _resolveCategoryPk(draft);
  }

  Future<String> _resolveWalletPk(TransactionDraft draft) async {
    if (draft.walletName != null && draft.walletName!.trim().isNotEmpty) {
      final walletName = draft.walletName!.trim().toLowerCase();
      final wallets = await database.getAllWallets();
      for (final wallet in wallets) {
        if (wallet.name.trim().toLowerCase() == walletName) {
          return wallet.walletPk;
        }
      }
    }
    return appStateSettings['selectedWalletPk'] as String? ?? "0";
  }

  DateTime _parseDate(TransactionDraft draft) {
    if (draft.date != null && draft.date!.trim().isNotEmpty) {
      try {
        return DateTime.parse(draft.date!.trim());
      } catch (_) {}
    }
    return DateTime.now();
  }

  Future<ConfirmResult> confirm(TransactionDraft draft) async {
    if (!draft.isValid) {
      throw ArgumentError('Draft is missing required fields (amount or title)');
    }

    final income = draft.income;
    final amount = draft.amount!;
    final signedAmount = income ? amount.abs() : -(amount.abs());

    final categoryPk = await _ensureCategory(draft, income);
    final walletPk = await _resolveWalletPk(draft);
    final date = _parseDate(draft);

    final transactionPk = uuid.v4();

    final transaction = Transaction(
      transactionPk: transactionPk,
      name: draft.title!,
      amount: signedAmount,
      note: draft.note ?? "",
      categoryFk: categoryPk ?? "0",
      walletFk: walletPk,
      dateCreated: date,
      income: income,
      paid: true,
      type: null,
      periodLength: null,
      endDate: null,
      subCategoryFk: null,
      pairedTransactionFk: null,
      upcomingTransactionNotification: null,
      createdAnotherFutureTransaction: null,
      skipPaid: false,
      methodAdded: null,
    );

    await database.createOrUpdateTransaction(transaction, insert: false);

    String? newCategoryPk;
    if (draft.createNewCategory) {
      newCategoryPk = categoryPk;
    }

    return ConfirmResult(
      transactionPk: transactionPk,
      newCategoryPk: newCategoryPk,
      newCategoryName: draft.newCategoryName,
    );
  }
}
