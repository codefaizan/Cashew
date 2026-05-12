import 'dart:math';

import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/ai/ai_chat_history.dart';
import 'package:budget/struct/ai/ai_context_builder.dart';
import 'package:budget/struct/ai/ai_intent_executor.dart';
import 'package:budget/struct/ai/ai_intent_parser.dart';
import 'package:budget/struct/ai/ai_intent_types.dart';
import 'package:budget/struct/ai/ai_provider.dart';
import 'package:budget/struct/ai/ai_provider_factory.dart';
import 'package:budget/struct/ai/ai_provider_gemini_nano.dart';
import 'package:budget/struct/ai/ai_response_formatter.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class AiChatMessage {
  final bool isUser;
  final String text;
  final AiExecutionResult? executionResult;
  final bool isTyping;

  AiChatMessage({
    required this.isUser,
    required this.text,
    this.executionResult,
    this.isTyping = false,
  });
}

enum AiChatState {
  initializing,
  ready,
  downloading,
  error,
  incompatible,
}

class AiAssistantChat extends StatefulWidget {
  const AiAssistantChat({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  State<AiAssistantChat> createState() => _AiAssistantChatState();
}

class _AiAssistantChatState extends State<AiAssistantChat> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ItemScrollController _itemScrollController = ItemScrollController();

  AiProvider? _provider;
  AiChatHistory? _chatHistory;
  AiChatState _state = AiChatState.initializing;
  String? _errorMessage;
  double _downloadProgress = 0;

  final List<AiChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _state = AiChatState.initializing;
    });

    _provider = AiProviderFactory.createProvider();
    _chatHistory = AiChatHistory()..loadFromSettings();

    final bool isAvailable = await _provider!.initialize();

    if (!isAvailable) {
      final isCompatible = await GeminiNanoProvider.isDeviceCompatible();
      if (!isCompatible) {
        setState(() {
          _state = AiChatState.incompatible;
        });
        _addWelcomeMessage();
        return;
      }

      if (appStateSettings['aiModelDownloaded'] != true) {
        setState(() {
          _state = AiChatState.downloading;
        });
        _addWelcomeMessage();
        return;
      }

      setState(() {
        _state = AiChatState.error;
        _errorMessage = _provider!.name + ' failed to initialize';
      });
      _addWelcomeMessage();
      return;
    }

    setState(() {
      _state = AiChatState.ready;
    });
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(AiChatMessage(
      isUser: false,
      text: _getWelcomeText(),
    ));
    _scrollToBottom();
  }

  String _getWelcomeText() {
    return 'Hi! I\'m Cashew AI. I can help you manage your finances faster. Try saying things like "add 500 coffee", "how much did I spend this month?", or "monthly budget 10k for food".';
  }

  List<String> _getSuggestionChips() {
    return [
      'add 500 coffee',
      'monthly budget 10k',
      'how much spent today?',
      'what\'s my net worth?',
    ];
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_messages.isNotEmpty) {
        _itemScrollController.scrollTo(
          index: _messages.length - 1,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<AllWallets> _getAllWallets() async {
    final wallets = await database.getAllWallets();
    return AllWallets(
      list: wallets,
      indexedByPk: {for (final w in wallets) w.walletPk: w},
    );
  }

  Future<String> _craftMessageWithLlm(
      String userQuery, AiExecutionResult result, AllWallets allWallets) async {
    final actionType = result.actionType ?? 'unknown';
    final createdObject = result.createdObject;

    String contextInfo = '';
    if (createdObject is Map) {
      if (actionType == 'spending_query') {
        final total = (createdObject['total'] as num?)?.toDouble() ?? 0;
        final count = createdObject['count'] ?? 0;
        final period = createdObject['period'] ?? 'month';
        final formattedTotal = convertToMoney(allWallets, total.abs());
        contextInfo =
            'User asked about spending. Result: Total $formattedTotal, $count transactions for $period.';
      } else if (actionType == 'net_worth_query') {
        final total = (createdObject['total'] as num?)?.toDouble() ?? 0;
        final walletCount = createdObject['walletCount'] ?? 0;
        final formattedTotal = convertToMoney(allWallets, total.abs());
        contextInfo =
            'User asked about net worth. Result: Total $formattedTotal across $walletCount accounts.';
      } else if (actionType == 'transaction_created') {
        contextInfo =
            'User requested to create a transaction. Result: Success.';
      } else if (actionType == 'budget_created') {
        contextInfo = 'User requested to create a budget. Result: Success.';
      } else if (actionType == 'budget_remaining_query') {
        final remaining = (createdObject['remaining'] as num?)?.toDouble() ?? 0;
        final spent = (createdObject['spent'] as num?)?.toDouble() ?? 0;
        final percentUsed =
            (createdObject['percentUsed'] as num?)?.toDouble() ?? 0;
        final formattedRemaining = convertToMoney(allWallets, remaining.abs());
        final formattedSpent = convertToMoney(allWallets, spent.abs());
        contextInfo =
            'User asked about budget remaining. Result: Spent $formattedSpent, Remaining $formattedRemaining (${percentUsed.toStringAsFixed(0)}% used).';
      } else {
        contextInfo = 'Action type: $actionType, Result data: $createdObject';
      }
    }

    final craftingPrompt = '''You are a friendly finance assistant. 
User said: "$userQuery"
$contextInfo

Write a natural, friendly response (1-2 sentences max). Don't mention the details unless relevant.''';

    final response = await _provider!.generateChatResponse(
      systemPrompt: '',
      history: [],
      userMessage: craftingPrompt,
    );

    return response;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_provider == null || _state != AiChatState.ready) return;

    setState(() {
      _messages.add(AiChatMessage(isUser: true, text: text));
      _messages.add(AiChatMessage(isUser: false, text: '', isTyping: true));
    });
    _scrollToBottom();

    _chatHistory?.addMessage(ChatMessage(role: 'user', content: text));

    try {
      final contextBuilder = AiContextBuilder();
      final systemPrompt = await contextBuilder.buildSystemPrompt();
      print(
          '=== AI PROMPT ===\n$systemPrompt\n=== USER MESSAGE ===\n$text\n===================');

      final response = await _provider!.generateChatResponse(
        systemPrompt: systemPrompt,
        history: _chatHistory?.messages ?? [],
        userMessage: text,
      );

      print('=== AI RESPONSE ===\n$response\n===================');

      setState(() {
        _messages.removeLast();
      });

      _chatHistory
          ?.addMessage(ChatMessage(role: 'assistant', content: response));

      final parser = AiIntentParser();
      final intent = parser.parseResponse(response);

      String periodInfo = '';
      if (intent is QuerySpendingIntent) {
        periodInfo = ', period: ${intent.period}';
      } else if (intent is AddTransactionIntent) {
        periodInfo = ', periodLength: ${intent.periodLength}';
      } else if (intent is AddBudgetIntent) {
        periodInfo = ', periodLength: ${intent.periodLength}';
      }
      print(
          '=== PARSED INTENT ===\nType: ${intent.runtimeType}$periodInfo\n===================');

      final executor = AiIntentExecutor();
      final result = await executor.execute(intent);

      final allWallets = await _getAllWallets();

      String formattedMessage;
      if (appStateSettings['aiUseLlmForMessages'] == true) {
        try {
          formattedMessage =
              await _craftMessageWithLlm(text, result, allWallets);
        } catch (e) {
          print('=== LLM MESSAGE CRAFTING FAILED === $e');
          final formatter = AiResponseFormatter(allWallets: allWallets);
          formattedMessage = formatter.format(result);
        }
      } else {
        final formatter = AiResponseFormatter(allWallets: allWallets);
        formattedMessage = formatter.format(result);
      }

      setState(() {
        _messages.add(AiChatMessage(
          isUser: false,
          text: formattedMessage,
          executionResult: result,
        ));
      });
    } catch (e) {
      print('=== CHAT ERROR === $e');
      setState(() {
        _messages.removeLast();
        _state = AiChatState.error;
        _errorMessage = e.toString();
        String errorMessage = 'Sorry, something went wrong. Please try again.';
        if (e.toString().contains('rate limit')) {
          errorMessage =
              'Rate limit exceeded. Please wait a moment and try again.';
        } else if (e.toString().contains('429')) {
          errorMessage = 'Too many requests. Please try again later.';
        }
        _messages.add(AiChatMessage(
          isUser: false,
          text: errorMessage,
        ));
      });
    }

    _scrollToBottom();
  }

  @override
  void dispose() {
    _provider?.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _buildMessageList(),
        ),
        if (_state == AiChatState.ready || _state == AiChatState.error)
          _buildInputArea(),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_state == AiChatState.incompatible) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 16),
              TextFont(
                text: 'Your device doesn\'t support on-device AI',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 8),
              TextFont(
                text: 'This feature requires a device with AI capabilities.',
                fontSize: 14,
                textColor: getColor(context, 'textColorLesser'),
              ),
            ],
          ),
        ),
      );
    }

    if (_state == AiChatState.downloading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_download_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 16),
              TextFont(
                text: 'Downloading AI model...',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 8),
              if (_downloadProgress > 0)
                LinearProgressIndicator(value: _downloadProgress),
              SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _state = AiChatState.ready;
                  });
                },
                child: TextFont(text: 'Skip & Continue'),
              ),
            ],
          ),
        ),
      );
    }

    if (_state == AiChatState.initializing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              TextFont(
                text: 'Initializing AI...',
                fontSize: 16,
              ),
            ],
          ),
        ),
      );
    }

    return ScrollablePositionedList.builder(
      itemCount: _messages.length,
      itemScrollController: _itemScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildChatBubble(message);
      },
    );
  }

  Widget _buildChatBubble(AiChatMessage message) {
    if (message.isTyping) {
      return _buildTypingIndicator();
    }

    return FadeIn(
      child: Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          decoration: BoxDecoration(
            color: message.isUser
                ? Theme.of(context).colorScheme.primary
                : appStateSettings["materialYou"]
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : getColor(context, "lightDarkAccentLight"),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 15,
                  color: message.isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (message.executionResult != null)
                _buildActionButton(message.executionResult!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: appStateSettings["materialYou"]
              ? Theme.of(context).colorScheme.secondaryContainer
              : getColor(context, "lightDarkAccentLight"),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedDots(),
            SizedBox(width: 8),
            ValueListenableBuilder<String>(
              valueListenable: _AnimatedDotsState.verbNotifier,
              builder: (context, verb, _) {
                return _TypingVerbText(verb: verb);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(AiExecutionResult result) {
    final formatter = AiResponseFormatter();
    final action = formatter.getViewAction(result);

    if (action == null) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Tappable(
        onTap: () {
          widget.onClose?.call();
        },
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFont(
            text: action.label,
            fontSize: 13,
            textColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appStateSettings["materialYou"]
            ? Theme.of(context).colorScheme.surface
            : getColor(context, "lightDarkAccent"),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_messages.length <= 1) _buildSuggestionChips(),
          Row(
            children: [
              Expanded(
                child: TextInput(
                  controller: _textController,
                  labelText: 'Type a message...',
                  autoFocus: false,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _sendMessage(value);
                      _textController.clear();
                    }
                  },
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  final text = _textController.text;
                  if (text.trim().isNotEmpty) {
                    _sendMessage(text);
                    _textController.clear();
                  }
                },
                icon: Icon(Icons.send),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = _getSuggestionChips();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: suggestions.map((suggestion) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: TextFont(
                text: suggestion,
                fontSize: 13,
              ),
              onPressed: () {
                _sendMessage(suggestion);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;
  static const _verbs = [
    'Thinking',
    'Processing',
    'Analyzing',
    'Computing',
    'Generating',
    'Consulting',
    'Reasoning',
    'Calculating',
    'Synthesizing',
    'Inferring',
    'Learning',
    'Adapting',
    'Optimizing',
    'Evaluating',
    'Classifying',
    'Searching',
    'Retrieving',
    'Matching',
    'Filtering',
    'Prioritizing',
    'Deciding',
    'Predicting',
    'Assessing',
    'Refining',
    'Executing'
  ];
  static final verbNotifier = ValueNotifier<String>('Thinking');
  final _random = Random();
  int _verbIndex = 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return false;
      _verbIndex = _random.nextInt(_verbs.length);
      verbNotifier.value = _verbs[_verbIndex];
      return mounted;
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.3 + _animations[index].value * 0.7),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

class _TypingVerbText extends StatefulWidget {
  final String verb;
  const _TypingVerbText({required this.verb});
  @override
  State<_TypingVerbText> createState() => _TypingVerbTextState();
}

class _TypingVerbTextState extends State<_TypingVerbText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<int> _textAnimation;
  String _displayText = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.verb.length * 30 + 100),
    );
    _textAnimation = IntTween(begin: 0, end: widget.verb.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _textAnimation.addListener(() {
      setState(
          () => _displayText = widget.verb.substring(0, _textAnimation.value));
    });
    _controller.forward();
  }

  @override
  void didUpdateWidget(_TypingVerbText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verb != widget.verb) {
      _controller.reset();
      _controller.duration =
          Duration(milliseconds: widget.verb.length * 50 + 100);
      _textAnimation = IntTween(begin: 0, end: widget.verb.length).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
      _textAnimation.addListener(() {
        if (mounted)
          setState(() =>
              _displayText = widget.verb.substring(0, _textAnimation.value));
      });
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFont(
      text: '$_displayText...',
      fontSize: 14,
      textColor: Theme.of(context).colorScheme.onSurface,
    );
  }
}
