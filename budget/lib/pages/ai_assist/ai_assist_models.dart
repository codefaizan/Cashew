import 'dart:convert';

class TransactionDraft {
  final bool income;
  final double? amount;
  final String? title;
  final String? categoryName;
  final bool createNewCategory;
  final String? newCategoryName;
  final String? walletName;
  final String? date;
  final String? note;

  const TransactionDraft({
    this.income = false,
    this.amount,
    this.title,
    this.categoryName,
    this.createNewCategory = false,
    this.newCategoryName,
    this.walletName,
    this.date,
    this.note,
  });

  TransactionDraft copyWith({
    bool? income,
    double? amount,
    String? title,
    String? categoryName,
    bool? createNewCategory,
    String? newCategoryName,
    String? walletName,
    String? date,
    String? note,
  }) {
    return TransactionDraft(
      income: income ?? this.income,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      categoryName: categoryName ?? this.categoryName,
      createNewCategory: createNewCategory ?? this.createNewCategory,
      newCategoryName: newCategoryName ?? this.newCategoryName,
      walletName: walletName ?? this.walletName,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'income': income,
        'amount': amount,
        'title': title,
        'categoryName': categoryName,
        'createNewCategory': createNewCategory,
        'newCategoryName': newCategoryName,
        'walletName': walletName,
        'date': date,
        'note': note,
      };

  factory TransactionDraft.fromJson(Map<String, dynamic> json) {
    return TransactionDraft(
      income: json['income'] as bool? ?? false,
      amount: (json['amount'] as num?)?.toDouble(),
      title: json['title'] as String?,
      categoryName: json['categoryName'] as String?,
      createNewCategory: json['createNewCategory'] as bool? ?? false,
      newCategoryName: json['newCategoryName'] as String?,
      walletName: json['walletName'] as String?,
      date: json['date'] as String?,
      note: json['note'] as String?,
    );
  }

  bool get isValid =>
      amount != null && amount! != 0 && (title?.isNotEmpty ?? false);
}

enum DraftStatus { pending, confirmed, discarded }

class ChatMessage {
  final String role;
  final String content;
  final TransactionDraft? draft;
  final DraftStatus? draftStatus;

  const ChatMessage({
    required this.role,
    required this.content,
    this.draft,
    this.draftStatus,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'draft': draft?.toJson(),
        'draftStatus': draftStatus?.name,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String? ?? '',
      draft: json['draft'] != null
          ? TransactionDraft.fromJson(json['draft'] as Map<String, dynamic>)
          : null,
      draftStatus: json['draftStatus'] != null
          ? DraftStatus.values.byName(json['draftStatus'] as String)
          : null,
    );
  }
}

class AiAssistResponse {
  final String assistantMessage;
  final TransactionDraft? draft;

  const AiAssistResponse({
    required this.assistantMessage,
    this.draft,
  });

  factory AiAssistResponse.fromJson(Map<String, dynamic> json) {
    TransactionDraft? draft;
    final d = json['draft'];
    if (d is Map<String, dynamic> && d.isNotEmpty) {
      final amount = d['amount'];
      final title = d['title'];
      if (amount != null || (title != null && (title as String).isNotEmpty)) {
        draft = TransactionDraft(
          income: d['income'] as bool? ?? false,
          amount: (amount as num?)?.toDouble(),
          title: title as String?,
          categoryName: d['categoryName'] as String?,
          createNewCategory: d['createNewCategory'] as bool? ?? false,
          newCategoryName: d['newCategoryName'] as String?,
          walletName: d['walletName'] as String?,
          date: d['date'] as String?,
          note: d['note'] as String?,
        );
      }
    }

    String message = json['assistantMessage'] as String? ?? '';
    if (message.isEmpty && draft == null) {
      message = jsonEncode(json);
    }

    return AiAssistResponse(
      assistantMessage: message,
      draft: draft,
    );
  }
}
