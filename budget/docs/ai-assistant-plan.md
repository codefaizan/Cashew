# AI Command Assistant — Implementation Plan

## Overview

Add an AI-powered command assistant to Cashew that lets users manage finances through natural language. Instead of tapping through menus, users type commands like "add 1200 rupees groceries" or "set a monthly food budget of 15k".

## Decisions Locked

- **LLM**: On-device provider-first strategy:
  - Primary: **Gemini Nano via Android AI Core** (no in-app model download)
  - Fallback: **`flutter_gemma` Gemma 4 E2B** for unsupported Nano devices
- **UI**: FAB long-press → "AI Assistant" as first option in `AddMoreThingsPopup`
- **Input**: Text-only for V1
- **Query results**: Inline response with optional [View Details] link
- **Fallback**: LLM-only (no rule-based offline fallback)
- **Abstraction**: `AiProvider` interface with runtime provider routing (`gemini_nano` → `gemma`)

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│              AI Command Assistant                │
├─────────────────────────────────────────────────┤
│                                                 │
│  [Text Input] ──────────────────────┐           │
│                                     ↓           │
│                          ┌──────────────────┐   │
│                          │  AiProvider      │   │
│                          │  (gemini_nano)   │   │
│                          │  fallback gemma  │   │
│                          └────────┬─────────┘   │
│                                   ↓             │
│                          ┌──────────────────┐   │
│                          │  Intent Parser   │   │
│                          │  (LLM JSON →     │   │
│                          │   AiIntent)      │   │
│                          └────────┬─────────┘   │
│                                   ↓             │
│                          ┌──────────────────┐   │
│                          │ Intent Executor  │   │
│                          │                  │   │
│                          │ • Transaction    │   │
│                          │ • Budget         │   │
│                          │ • Goal/Objective │   │
│                          │ • Query          │   │
│                          │ • Navigate       │   │
│                          │ • Pay/Skip       │   │
│                          └────────┬─────────┘   │
│                                   ↓             │
│                          ┌──────────────────┐   │
│                          │ Response         │   │
│                          │ Formatter        │   │
│                          │ (natural lang)   │   │
│                          └──────────────────┘   │
└─────────────────────────────────────────────────┘
```

---

## Supported Intents

| Intent | Example | Execution |
|--------|---------|-----------|
| **Add Expense** | "add 1200 rupees groceries" | `createOrUpdateTransaction()` |
| **Add Income** | "received 5000 salary" | `createOrUpdateTransaction()` |
| **Add Subscription** | "Netflix 499 monthly" | `createOrUpdateTransaction()` with type=subscription |
| **Add Debt/Credit** | "lent 5000 to John" | `createOrUpdateTransaction()` with type=credit/debt |
| **Create Budget** | "monthly food budget of 15k" | `createOrUpdateBudget()` |
| **Create Goal** | "save 50k for vacation" | `createOrUpdateObjective()` |
| **Query Spending** | "how much did I spend this month?" | DB query + response formatter |
| **Query Budget** | "how much left in food budget?" | DB query + response formatter |
| **Query Net Worth** | "what's my net worth?" | DB query + response formatter |
| **Navigate** | "show my subscriptions" | `pushRoute()` / `changePage()` |
| **Pay/Mark** | "pay my Netflix subscription" | `markAsPaid()` |

---

## New Files (12 files)

```
lib/struct/ai/
├── ai_provider.dart              # Abstract AiProvider interface
├── ai_provider_gemini_nano.dart  # Android AI Core Gemini Nano implementation
├── ai_provider_gemma.dart        # flutter_gemma on-device implementation
├── ai_intent_parser.dart         # LLM response → ParsedIntent
├── ai_intent_executor.dart       # ParsedIntent → DB/UI action
├── ai_intent_types.dart          # Intent & param type definitions
├── ai_response_formatter.dart    # ExecutionResult → natural language
├── ai_context_builder.dart       # Builds system prompt from user's data
└── ai_chat_history.dart          # Chat session management

lib/widgets/
├── aiAssistant.dart              # Assistant bottom sheet wrapper
└── aiAssistantChat.dart          # Chat UI, message bubbles, input, suggestions

lib/pages/
└── aiSettingsPage.dart           # AI model management & settings
```

## Modified Files (5 files)

| File | Change |
|------|--------|
| `lib/widgets/navigationFramework.dart` | Add "AI Assistant" as first `AddThing` in `AddMoreThingsPopup` |
| `lib/struct/defaultPreferences.dart` | Add AI-related default settings |
| `lib/struct/settings.dart` | Initialize AI settings on startup |
| `lib/pages/settingsPage.dart` | Add AI settings entry in "Tools & Extras" section |
| `budget/pubspec.yaml` | Add provider dependencies (`flutter_gemma` fallback, Android plugins if needed) |

---

## Detailed File Specifications

### 1. `lib/struct/ai/ai_provider.dart` — Abstract Interface

```dart
abstract class AiProvider {
  String get name;
  bool get isAvailable;
  Future<bool> initialize();
  Future<String> generateChatResponse({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  });
  Future<void> dispose();
}

class ChatMessage {
  final String role; // "user" | "assistant"
  final String content;
  ChatMessage({required this.role, required this.content});
}
```

### 2. `lib/struct/ai/ai_provider_gemini_nano.dart` — Gemini Nano Primary Provider

Key responsibilities:
- Bridge to Android AI Core APIs via platform channel
- Check runtime capability/support status on current device
- Initialize Gemini Nano session on-demand
- Send chat prompts + history and return model response text
- Report unsupported/error states cleanly to UI
- Implement `AiProvider` interface

### 3. `lib/struct/ai/ai_provider_gemma.dart` — Gemma Fallback Provider

Key responsibilities:
- Preserve existing `flutter_gemma` path for devices without Gemini Nano support
- Manage model download + initialization + response generation
- Surface download progress and failures to the same UI layer
- Implement `AiProvider` interface

### 4. `lib/struct/ai/ai_intent_types.dart` — Type Definitions

```dart
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
}

class AddBudgetIntent extends AiIntent {
  String? name;
  double? amount;
  BudgetReoccurrence reoccurrence;
  int periodLength;
  List<String>? categoryNames;
  String? walletName;
}

class AddObjectiveIntent extends AiIntent {
  ObjectiveType type;
  String? name;
  double? amount;
  bool isIncome;
  String? endDate;
}

class QuerySpendingIntent extends AiIntent {
  String? period;       // "today", "this week", "this month", "this year"
  String? categoryName;
  String? budgetName;
  bool? isIncome;
}

class QueryBudgetRemainingIntent extends AiIntent {
  String? budgetName;
}

class QueryNetWorthIntent extends AiIntent {}

class NavigateIntent extends AiIntent {
  String target; // "subscriptions", "goals", "settings", etc.
}

class PayTransactionIntent extends AiIntent {
  String? transactionName;
  String? action; // "pay", "skip"
}

class UnclearIntent extends AiIntent {
  String? clarificationNeeded;
}

class AiExecutionResult {
  final bool success;
  final String? message;
  final String? actionType; // "transaction", "budget", "objective", "query", "navigate"
  final String? detailRoute; // route to push for [View Details]
  final dynamic createdObject; // the created Transaction/Budget/Objective
}
```

### 4. `lib/struct/ai/ai_context_builder.dart` — Dynamic System Prompt

This is the most critical file for a 2B model. The prompt must be:
- Extremely structured and explicit
- Include the user's actual data (categories, wallets, budgets)
- Use few-shot examples for each intent type
- Define exact JSON output schema
- Stay compact (2B models have limited context windows)

```
System prompt structure:
1. Role definition (2 lines)
2. Available intents with JSON schemas (30 lines)
3. User's categories list (dynamic)
4. User's wallets list (dynamic)
5. User's budgets list (dynamic)
6. Currency info (2 lines)
7. Today's date (1 line)
8. 2 few-shot examples per intent (40 lines)
9. Output format instruction (3 lines)
```

The context is rebuilt each time the user opens the assistant, ensuring fresh data.

### 5. `lib/struct/ai/ai_intent_parser.dart` — Response Parser

- Takes the raw LLM text output
- Extracts JSON (handles cases where LLM adds extra text around JSON)
- Deserializes into the appropriate `AiIntent` subclass based on the `intent` field
- Validates required fields per intent type
- On parse failure → returns `UnclearIntent` with the raw output
- On ambiguous input (e.g., category not found) → returns intent with `categoryName` set, executor handles disambiguation

### 6. `lib/struct/ai/ai_intent_executor.dart` — Execution Engine

For each intent type, performs DB operations using the existing global `database`:

| Intent | Execution |
|--------|-----------|
| `AddTransactionIntent` | Resolve category name→`categoryFk` via `database.getCategoryByName()`. Resolve wallet name→`walletFk`. Call `database.createOrUpdateTransaction(insert: true, ...)`. Call `addAssociatedTitles()`. Return `AiExecutionResult` with the created transaction. |
| `AddBudgetIntent` | Resolve categories/wallets. Call `database.createOrUpdateBudget(insert: true, ...)`. |
| `AddObjectiveIntent` | Call `database.createOrUpdateObjective(insert: true, ...)`. For loans, auto-create initial transaction. |
| `QuerySpendingIntent` | Resolve time period → DateTimeRange. Query `database.getTransactionsInDateRange()`. Aggregate by category. Format totals. |
| `QueryBudgetRemainingIntent` | Find budget by name. Calculate spent vs. total. Return remaining amount. |
| `QueryNetWorthIntent` | Sum all wallet balances. Return total. |
| `NavigateIntent` | Map target string to page index. Call `PageNavigationFramework.changePage()`. |
| `PayTransactionIntent` | Find upcoming/subscription by name. Call `markAsPaid()`. |
| `UnclearIntent` | Return result asking user to clarify. |

Category resolution strategy:
1. Exact name match (case-insensitive)
2. Partial match (contains)
3. Associated titles lookup
4. If no match → create new category (with user confirmation)

### 7. `lib/struct/ai/ai_response_formatter.dart` — Natural Language Output

Takes `AiExecutionResult` and produces a human-friendly string:
- "Added ₹1,200 expense to Groceries"
- "Created budget 'Food' with ₹15,000 monthly limit"
- "You spent ₹12,450 this month across 8 transactions. Top categories: Groceries ₹4,200, Dining ₹3,100..."
- "Budget 'Food' has ₹8,500 remaining of ₹15,000"
- "Your net worth is ₹2,45,000 across 3 accounts"

Also produces the [View Details] action label and route.

### 8. `lib/struct/ai/ai_chat_history.dart` — Session Management

- Maintains a `List<ChatMessage>` for the current session
- Truncates to last N messages (e.g., 10) to stay within context window
- Persists last session to `appStateSettings["aiChatHistory"]`
- Clears on explicit user action
- Does NOT persist across app restarts (privacy)

### 9. `lib/widgets/aiAssistant.dart` — Bottom Sheet Wrapper

- Uses `openBottomSheet()` with `fullSnap: true`
- Contains `AiAssistantChat` widget
- Handles model availability check:
  - If model not downloaded → show download prompt
  - If model initializing → show loading spinner
  - If model ready → show chat interface

### 10. `lib/widgets/aiAssistantChat.dart` — Chat UI

```
┌──────────────────────────────────────┐
│ 🤖 Cashew AI                    [✕] │
│──────────────────────────────────────│
│                                      │
│ [Chat message list - scrollable]     │
│                                      │
│ Welcome message (first time):        │
│ "Hi! I can help you manage your      │
│  finances. Try saying:"              │
│                                      │
│ 💡 [add 500 coffee] [monthly budget] │
│    [how much spent today?]           │
│                                      │
│──────────────────────────────────────│
│ ┌──────────────────────────┐ [➤]    │
│ │ Type a command...        │         │
│ └──────────────────────────┘         │
└──────────────────────────────────────┘
```

Components:
- **Message list**: `ListView.builder` with `AiChatBubble` widgets
  - User messages: right-aligned, primary color
  - AI messages: left-aligned, secondary container color
  - AI messages with actions: includes tappable [View Transaction/Budget] button
  - Loading state: typing indicator animation
- **Input bar**: `TextInput` widget (existing) + send button
- **Suggestion chips**: Horizontal scrollable `SelectChips` (existing widget) with example commands
- **Error states**: "Model not downloaded" → download button, "Parse error" → "I didn't understand that" message

### 11. `lib/pages/aiSettingsPage.dart` — Settings Page

- Model download status & storage size
- Download/delete model buttons
- Download progress indicator (if downloading)
- Toggle: confirm before executing actions (default: true)
- Toggle: send financial context to model (default: true, privacy note)
- Clear chat history button
- Device compatibility info (RAM, NPU support)
- "About AI Assistant" info section

---

## Settings Additions (`defaultPreferences.dart`)

```dart
"aiEnabled": true,
"aiModelDownloaded": false,
"aiModelPath": "",
"aiConfirmActions": true,
"aiSendContext": true,
"aiChatHistory": <String>[],
"aiLastUsedProvider": "gemini_nano",
```

---

## Integration Points

### `AddMoreThingsPopup` in `navigationFramework.dart`

Add AI Assistant as the first item (before Account):

```dart
AddThing(
  iconData: Icons.auto_awesome,
  title: "AI Assistant",
  onTap: () {
    popRoute(context);
    openBottomSheet(
      context,
      fullSnap: true,
      AiAssistantSheet(),
    );
  },
),
```

### Settings Page in `settingsPage.dart`

In "Tools & Extras" section, add:

```dart
SettingsContainerOpenPage(
  openPage: AiSettingsPage(),
  title: "AI Assistant",
  icon: Icons.auto_awesome,
  description: "Manage AI model and preferences",
),
```

### pubspec.yaml Addition

```yaml
dependencies:
  # optional fallback provider
  flutter_gemma: ^0.13.2
```

### Android Manifest

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-feature android:name="android.hardware.opengles.aep" android:required="false"/>
```

---

## Error Handling Strategy

| Scenario | Response |
|----------|----------|
| Model not downloaded | Show download prompt in assistant sheet |
| Model download fails | Retry with error message, option to retry |
| Device incompatible | Show "Your device doesn't support on-device AI" message |
| LLM returns invalid JSON | "I didn't understand that. Could you rephrase?" |
| Category not found | "I couldn't find a category matching 'X'. Should I create one?" with Yes/No |
| Amount missing | "How much was the transaction?" |
| Ambiguous input | "Did you mean Dining or Groceries?" with chip selectors |
| DB write fails | "Something went wrong saving. Please try again." |
| LLM timeout (slow device) | Show thinking indicator, 30s timeout → error message |

---

## Implementation Order

1. `ai_intent_types.dart` — Pure types, no dependencies
2. `ai_provider.dart` — Abstract interface
3. `ai_provider_gemini_nano.dart` — Gemini Nano wrapper (primary)
4. `ai_provider_gemma.dart` — Gemma wrapper (fallback)
5. `ai_context_builder.dart` — System prompt builder
6. `ai_intent_parser.dart` — LLM response → Intent
7. `ai_intent_executor.dart` — Intent → Action
8. `ai_response_formatter.dart` — Action → Natural language
9. `ai_chat_history.dart` — Session management
10. `aiAssistantChat.dart` — Chat UI
11. `aiAssistant.dart` — Sheet wrapper
12. `aiSettingsPage.dart` — Settings page
13. Modify `navigationFramework.dart` — Add to FAB popup
14. Modify `defaultPreferences.dart` — Add settings
15. Modify `settingsPage.dart` — Add settings entry
16. Modify `pubspec.yaml` — Provider dependencies

---

## Risk: 2B Model Quality

A 2B parameter model has limited reasoning. Mitigations:
- System prompt includes 2 few-shot examples per intent (total ~10 examples)
- JSON schema is minimal (no nested objects)
- Intent classification is separate from parameter extraction (two-pass if needed)
- The prompt explicitly lists the user's category names so the model doesn't hallucinate
- `UnclearIntent` catches all failures gracefully
- If Gemini Nano is unavailable or insufficient on a device, `AiProvider` routing falls back to Gemma

---

## Provider Details

### Gemini Nano (Primary)

| Attribute | Value |
|-----------|-------|
| Runtime | Android AI Core |
| Download | No in-app model download flow |
| Device scope | Supported Android devices only |
| UX | Fast setup on compatible devices |

### Gemma via flutter_gemma (Fallback)

| Attribute | Value |
|-----------|-------|
| Package | `flutter_gemma: ^0.13.2` |
| Runtime | MediaPipe / LiteRT-LM |
| Model format | `.litertlm` / `.task` (model-dependent) |
| Download | In-app download with progress |
| Device scope | Wider than Nano, but heavy model download |
