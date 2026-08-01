import 'dart:async';
import 'package:flutter/material.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/ai_assist/ai_assist_confirm.dart';
import 'package:budget/pages/ai_assist/ai_assist_models.dart';
import 'package:budget/pages/ai_assist/ai_assist_session.dart';
import 'package:budget/pages/ai_assist/openrouter_client.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:intl/intl.dart';

class AiAssistChat extends StatefulWidget {
  final ScrollController scrollController;

  const AiAssistChat({super.key, required this.scrollController});

  @override
  State<AiAssistChat> createState() => _AiAssistChatState();
}

class _AiAssistChatState extends State<AiAssistChat> {
  AiAssistSession _session = const AiAssistSession();
  bool _isLoading = false;
  String? _error;
  String _apiKey = '';
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  List<TransactionCategory> _categories = [];
  Map<String, TransactionWallet> _wallets = {};

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadKey();
    _loadData();
  }

  Future<void> _loadSession() async {
    final session = await AiAssistSession.load();
    setState(() => _session = session);
  }

  Future<void> _loadKey() async {
    setState(() {
      _apiKey = appStateSettings['aiAssistOpenRouterApiKey'] ?? '';
    });
  }

  Future<void> _loadData() async {
    final cats = await database.getAllCategories();
    final wallets = await database.getAllWallets();
    final walletsMap = <String, TransactionWallet>{};
    for (final w in wallets) {
      walletsMap[w.walletPk] = w;
    }
    setState(() {
      _categories = cats;
      _wallets = walletsMap;
    });
  }

  List<String> get _categoryNames =>
      _categories.map((c) => c.name).toList();

  String get _defaultWalletName {
    final pk = appStateSettings['selectedWalletPk'] as String? ?? '0';
    return _wallets[pk]?.name ?? 'Default';
  }

  Map<String, String> get _walletNamesWithCurrencies {
    final m = <String, String>{};
    for (final w in _wallets.values) {
      m[w.name] = w.currency ?? 'USD';
    }
    return m;
  }

  String get _currentDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (_apiKey.isEmpty) {
      setState(() => _error = 'Please add your OpenRouter API key in Settings');
      return;
    }

    _textController.clear();
    setState(() {
      _error = null;
      _isLoading = true;
    });

    final userMessage = ChatMessage(role: 'user', content: text);
    _session = _session.copyWith(
      messages: [..._session.messages, userMessage],
    );
    await _session.save();

    try {
      final client = HttpOpenRouterClient(apiKey: _apiKey);
      final response = await client.sendMessage(
        userMessage: text,
        history: _session.messages,
        categoryNames: _categoryNames,
        walletNamesWithCurrencies: _walletNamesWithCurrencies,
        defaultWalletName: _defaultWalletName,
        currentDate: _currentDate,
        currentDraft: _session.currentDraft,
      );

      final assistantMessage = ChatMessage(
        role: 'assistant',
        content: response.assistantMessage,
        draft: response.draft,
        draftStatus: response.draft != null ? DraftStatus.pending : null,
      );

      _session = _session.copyWith(
        messages: [..._session.messages, assistantMessage],
        currentDraft: response.draft ?? _session.currentDraft,
      );
      await _session.save();

      setState(() => _isLoading = false);
    } on OpenRouterAuthException {
      setState(() {
        _error = 'Invalid API key. Check your OpenRouter key in Settings.';
        _isLoading = false;
      });
    } on OpenRouterRateLimitException {
      setState(() {
        _error =
            'Rate limited by OpenRouter. Please wait a moment and try again.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _confirmDraft(TransactionDraft draft) async {
    setState(() => _isLoading = true);
    try {
      final handler = AiAssistConfirmHandler();
      await handler.confirm(draft);

      final updatedMessages = _session.messages.map((m) {
        if (m.draftStatus == DraftStatus.pending) {
          return ChatMessage(
            role: m.role,
            content: m.content,
            draft: m.draft,
            draftStatus: DraftStatus.confirmed,
          );
        }
        return m;
      }).toList();

      _session = _session.copyWith(
        messages: updatedMessages,
        currentDraft: null,
      );
      await _session.save();

      // Reload to get new category if created
      await _loadData();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to create transaction: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _discardDraft() {
    final updatedMessages = <ChatMessage>[];
    bool found = false;
    for (int i = _session.messages.length - 1; i >= 0; i--) {
      final m = _session.messages[i];
      if (!found && m.draftStatus == DraftStatus.pending) {
        updatedMessages.insert(0, ChatMessage(
          role: m.role,
          content: m.content,
          draft: m.draft,
          draftStatus: DraftStatus.discarded,
        ));
        found = true;
      } else {
        updatedMessages.insert(0, m);
      }
    }

    _session = _session.copyWith(
      messages: updatedMessages,
      currentDraft: null,
    );
    _session.save();
    setState(() {});
  }

  void _newChat() {
    AiAssistSession.clear();
    _textController.clear();
    setState(() {
      _session = const AiAssistSession();
      _error = null;
    });
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final popColor = getPopupBackgroundColor(context);
    return Container(
      color: popColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, popColor),
            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount:
                    _session.messages.length + (_isLoading ? 1 : 0) + (_error != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _session.messages.length) {
                    return _buildMessageBubble(
                        _session.messages[index], index);
                  }
                  if (_isLoading &&
                      index == _session.messages.length) {
                    return _buildLoadingBubble();
                  }
                  return _buildErrorBubble();
                },
              ),
            ),
            _buildInputBar(context, popColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color popColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: popColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            child: TextFont(
              text: 'AI Assist',
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            onPressed: _newChat,
            child: TextFont(
              text: 'New chat',
              fontSize: 13,
              textColor: Theme.of(context).colorScheme.primary,
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isUser = message.role == 'user';
    final hasDraft = message.draft != null;
    final isPending = message.draftStatus == DraftStatus.pending;
    final isConfirmed = message.draftStatus == DraftStatus.confirmed;
    final isDiscarded = message.draftStatus == DraftStatus.discarded;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 320),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.5)
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextFont(
                    text: message.content,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (hasDraft && isPending) _buildDraftCard(message.draft!),
          if (hasDraft && isConfirmed) _buildConfirmedCard(),
          if (hasDraft && isDiscarded) _buildDiscardedCard(),
        ],
      ),
    );
  }

  Widget _buildDraftCard(TransactionDraft draft) {
    return Padding(
      padding: EdgeInsetsDirectional.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  draft.income
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 16,
                  color: draft.income ? Colors.green : Colors.red,
                ),
                SizedBox(width: 6),
                TextFont(
                  text: draft.income ? 'Income' : 'Expense',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  textColor: draft.income ? Colors.green : Colors.red,
                ),
                Spacer(),
                if (draft.date != null)
                  TextFont(
                    text: draft.date!,
                    fontSize: 12,
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                if (draft.amount != null)
                  TextFont(
                    text: '\$${draft.amount!.toStringAsFixed(2)}',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                if (draft.title != null) ...[
                  if (draft.amount != null) SizedBox(width: 8),
                  Expanded(
                    child: TextFont(
                      text: draft.title!,
                      fontSize: 16,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
            if (draft.categoryName != null || draft.newCategoryName != null) ...[
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.category_outlined, size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  SizedBox(width: 4),
                  Expanded(
                    child: TextFont(
                      text: draft.createNewCategory
                          ? 'New: ${draft.newCategoryName ?? draft.categoryName ?? ""}'
                          : draft.categoryName ?? '',
                      fontSize: 13,
                      textColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (draft.walletName != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  SizedBox(width: 4),
                  TextFont(
                    text: draft.walletName!,
                    fontSize: 13,
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
            if (draft.note != null && draft.note!.isNotEmpty) ...[
              SizedBox(height: 4),
              TextFont(
                text: draft.note!,
                fontSize: 12,
                textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                maxLines: 3,
              ),
            ],
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : _discardDraft,
                  child: TextFont(
                    text: 'Discard',
                    fontSize: 13,
                    textColor: Theme.of(context).colorScheme.error,
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLoading ? null : () => _confirmDraft(draft),
                  child: TextFont(
                    text: 'Confirm',
                    fontSize: 13,
                    textColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmedCard() {
    return Padding(
      padding: EdgeInsetsDirectional.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 20, color: Colors.green),
            SizedBox(width: 8),
            TextFont(
              text: 'Added',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              textColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscardedCard() {
    return Padding(
      padding: EdgeInsetsDirectional.only(top: 8),
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextFont(
          text: 'Draft discarded',
          fontSize: 12,
          textColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: 320),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 40,
              height: 20,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBubble() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextFont(
          text: _error!,
          fontSize: 12,
          textColor: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, Color popColor) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: popColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _inputFocusNode,
              enabled: !_isLoading,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText:
                    _apiKey.isEmpty ? 'Add API key in Settings first...' : 'Describe a transaction...',
                hintStyle: TextStyle(fontSize: 14),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              style: TextStyle(fontSize: 14),
              maxLines: null,
            ),
          ),
          SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.send_rounded, size: 22),
            onPressed: _isLoading ? null : _sendMessage,
            color: _isLoading
                ? Theme.of(context).disabledColor
                : Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
