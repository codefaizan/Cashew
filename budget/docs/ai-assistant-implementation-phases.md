# AI Command Assistant — Phased Implementation Plan

## Phase 0: Project Setup & Dependencies

| # | Task | Measurable Output | Status |
|---|------|-------------------|--------|
| 0.1 | Confirm provider strategy in docs/settings (`gemini_nano` first, `gemma` fallback) | Decisions and settings keys aligned | ✅ |
| 0.2 | Run `flutter pub get` in `budget/` | Dependencies resolve cleanly | ✅ |
| 0.3 | Add Android native bridge scaffolding for Gemini Nano provider | MethodChannel endpoint exists and compiles | ✅ |
| 0.4 | Create `lib/struct/ai/` directory | Directory exists | ✅ |
| 0.5 | Add AI default settings to `lib/struct/defaultPreferences.dart` | 6 new keys added: `aiEnabled`, `aiModelDownloaded`, `aiModelPath`, `aiConfirmActions`, `aiSendContext`, `aiChatHistory` | ✅ |
| 0.6 | Verify app still builds after provider dependency updates | `flutter build appbundle --debug` succeeds | ✅ |

**Phase 0 Exit Criteria:** App builds with Gemini Nano primary path prepared and no existing functionality broken.

---

## Phase 1: Core Type System & Provider Abstraction

| # | Task | Measurable Output | Status |
|---|------|-------------------|--------|
| 1.1 | Create `lib/struct/ai/ai_intent_types.dart` | File with 9 intent classes: `AddTransactionIntent`, `AddBudgetIntent`, `AddObjectiveIntent`, `QuerySpendingIntent`, `QueryBudgetRemainingIntent`, `QueryNetWorthIntent`, `NavigateIntent`, `PayTransactionIntent`, `UnclearIntent` + `AiExecutionResult` class | ✅ |
| 1.2 | Create `lib/struct/ai/ai_provider.dart` | File with `AiProvider` abstract class (4 methods: `name`, `isAvailable`, `initialize`, `generateChatResponse`, `dispose`) + `ChatMessage` class | ✅ |
| 1.3 | Create `lib/struct/ai/ai_chat_history.dart` | File with `AiChatHistory` class: `addMessage`, `getMessages`, `clear`, `truncateToLast` (N=10), serialization to/from settings | ✅ |
| 1.4 | Write unit test: `AiChatHistory` truncation | Test that adding 15 messages and truncating keeps only last 10 | ✅ |
| 1.5 | Write unit test: `AiExecutionResult` construction | Test success/failure result objects with all fields | ✅ |

**Phase 1 Exit Criteria:** All type definitions compile. `AiProvider` interface is final. Chat history truncation works. Provider abstraction is runtime-switchable.

---

## Phase 2: Primary Provider Implementation (Gemini Nano)

| # | Task | Measurable Output | Status |
|---|------|-------------------|--------|
| 2.1 | Create `lib/struct/ai/ai_provider_gemini_nano.dart` | File with `GeminiNanoProvider implements AiProvider` | ✅ |
| 2.2 | Implement Android availability check | `isAvailableOnDevice()` returns bool from native bridge/AI Core check | ✅ |
| 2.3 | Implement provider initialization | `initialize()` opens/warms Nano session and returns bool | ✅ |
| 2.4 | Implement prompt request path | `generateChatResponse()` sends `systemPrompt + history + userMessage` and returns text | ✅ |
| 2.5 | Implement `dispose()` | Closes/cleans provider resources | ✅ |
| 2.6 | Implement error mapping | Native/provider errors map to user-safe messages and retry states | ✅ |
| 2.7 | Implement compatibility surface | Unsupported devices return deterministic unavailability state | ✅ |
| 2.8 | Add integration hook in provider router | App chooses `gemini_nano` first when available | ✅ |
| 2.9 | Test: initialize + generate on supported Android device | Nano responds with non-empty text for "Hello" | 🟨 |

**Phase 2 Exit Criteria:** `GeminiNanoProvider` initializes and generates text on supported Android devices. Unsupported devices return a deterministic unavailable state.

---

## Phase 2B: Fallback Provider Implementation (flutter_gemma)

| # | Task | Measurable Output | Status |
|---|------|-------------------|--------|
| 2B.1 | Keep `lib/struct/ai/ai_provider_gemma.dart` as fallback provider | File compiles and implements `AiProvider` | ⏸️ |
| 2B.2 | Validate fallback download flow | Model download + progress + cancel works | ⏸️ |
| 2B.3 | Validate fallback initialize/generate flow | Non-empty response for simple prompt | ⏸️ |
| 2B.4 | Wire provider routing fallback | If Nano unavailable/error, app uses Gemma | ⏸️ |

**Phase 2B Exit Criteria:** Gemma remains a working fallback path on devices without Gemini Nano support.

---

## Phase 3: Context Builder & Intent Parser

| # | Task | Measurable Output | Status |
|---|------|-------------------|--------|
| 3.1 | Create `lib/struct/ai/ai_context_builder.dart` | File with `AiContextBuilder` class | ✅ |
| 3.2 | Implement `buildSystemPrompt()` | Returns system prompt string with: role definition, intent schemas, user categories, wallets, budgets, currency, date, few-shot examples, output format | ✅ |
| 3.3 | Implement `getUserCategories()` | Queries `database.getAllCategories()`, formats as name list | ✅ |
| 3.4 | Implement `getUserWallets()` | Queries `database.getAllWallets()`, formats as name+currency list | ✅ |
| 3.5 | Implement `getUserBudgets()` | Queries `database.getAllBudgets()`, formats as name+amount list | ✅ |
| 3.6 | Create `lib/struct/ai/ai_intent_parser.dart` | File with `AiIntentParser` class | ✅ |
| 3.7 | Implement `parseResponse(String rawOutput)` | Extracts JSON from LLM text (handles surrounding prose), deserializes into `AiIntent` subclass | ✅ |
| 3.8 | Implement JSON extraction | Regex to find `{...}` in mixed text output | ✅ |
| 3.9 | Implement `AddTransactionIntent` deserialization | JSON → `AddTransactionIntent` with all fields mapped | ✅ |
| 3.10 | Implement `AddBudgetIntent` deserialization | JSON → `AddBudgetIntent` with all fields mapped | ✅ |
| 3.11 | Implement `AddObjectiveIntent` deserialization | JSON → `AddObjectiveIntent` with all fields mapped | ✅ |
| 3.12 | Implement `QuerySpendingIntent` deserialization | JSON → `QuerySpendingIntent` with period/category fields | ✅ |
| 3.13 | Implement `QueryBudgetRemainingIntent` deserialization | JSON → `QueryBudgetRemainingIntent` | ✅ |
| 3.14 | Implement `QueryNetWorthIntent` deserialization | JSON → `QueryNetWorthIntent` | ✅ |
| 3.15 | Implement `NavigateIntent` deserialization | JSON → `NavigateIntent` with target mapping | ✅ |
| 3.16 | Implement `PayTransactionIntent` deserialization | JSON → `PayTransactionIntent` | ✅ |
| 3.17 | Implement `UnclearIntent` fallback | Invalid/missing JSON → `UnclearIntent` with raw output | ✅ |
| 3.18 | Write test: parser handles 10 valid JSON inputs | Each intent type deserialized correctly from LLM-like output | ✅ |
| 3.19 | Write test: parser handles 5 invalid inputs | Invalid JSON, empty, partial JSON → `UnclearIntent` | ✅ |
| 3.20 | Write test: context builder includes user data | Built prompt contains category names, wallet names, today's date | ✅ |

**Phase 3 Exit Criteria:** System prompt is dynamically built with real user data. Parser correctly deserializes all 8 intent types from JSON. Parser gracefully handles all error cases.

---

## Phase 4: Intent Executor

| # | Task | Measurable Output | Status |
|---|------|-------------------|--------|
| 4.1 | Create `lib/struct/ai/ai_intent_executor.dart` | File with `AiIntentExecutor` class | ✅ |
| 4.2 | Implement `execute(AddTransactionIntent)` | Resolves category→Fk, wallet→Fk, creates `Transaction`, calls `database.createOrUpdateTransaction(insert: true)`, calls `addAssociatedTitles()`, returns `AiExecutionResult` | ✅ |
| 4.3 | Implement category name resolution | `resolveCategoryFk(name)`: exact match → partial match → associated titles → null (flag for creation) | ✅ |
| 4.4 | Implement wallet name resolution | `resolveWalletFk(name)`: exact match → partial match → default wallet | ✅ |
| 4.5 | Implement `execute(AddBudgetIntent)` | Resolves categories/wallets, creates `Budget`, calls `database.createOrUpdateBudget(insert: true)` | ✅ |
| 4.6 | Implement `execute(AddObjectiveIntent)` | Creates `Objective`, calls `database.createOrUpdateObjective(insert: true)`, auto-creates loan transaction if type=loan | ✅ |
| 4.7 | Implement `execute(QuerySpendingIntent)` | Resolves period→DateTimeRange, queries transactions, aggregates by category, returns totals | ✅ |
| 4.8 | Implement time period resolution | `resolveTimePeriod(period)`: "today"→today, "this week"→monday-today, "this month"→1st-today, "this year"→jan1-today | ✅ |
| 4.9 | Implement `execute(QueryBudgetRemainingIntent)` | Finds budget by name, calculates spent, returns remaining | ✅ |
| 4.10 | Implement `execute(QueryNetWorthIntent)` | Sums all wallet balances, returns total | ✅ |
| 4.11 | Implement `execute(NavigateIntent)` | Maps target string to page index, calls `PageNavigationFramework.changePage()` | ✅ |
| 4.12 | Implement navigation target mapping | "subscriptions"→5, "goals"→14, "settings"→settings page, etc. | ✅ |
| 4.13 | Implement `execute(PayTransactionIntent)` | Finds upcoming/subscription by name, calls `markAsPaid()` | ✅ |
| 4.14 | Implement `execute(UnclearIntent)` | Returns `AiExecutionResult` with clarification message | ✅ |
| 4.15 | Write test: `AddTransactionIntent` creates a transaction | Transaction appears in DB with correct name, amount, categoryFk | ✅ |
| 4.16 | Write test: `AddBudgetIntent` creates a budget | Budget appears in DB with correct name, amount, reoccurrence | ✅ |
| 4.17 | Write test: category resolution exact match | "Groceries" → existing Groceries categoryFk | ✅ |
| 4.18 | Write test: category resolution partial match | "groc" → Groceries categoryFk | ✅ |
| 4.19 | Write test: category resolution null | "xyz123" → null, flag for creation | ✅ |
| 4.20 | Write test: time period resolution | "this month" → DateTimeRange from 1st to today | ✅ |

**Phase 4 Exit Criteria:** All 8 intent types execute correctly against the database. Category/wallet resolution works with fuzzy matching. Transactions, budgets, and objectives can be created via intents. Queries return accurate data.

---

## Phase 5: Response Formatter

| # | Task | Measurable Output | Status |
|---|------|-------------------|--------|
| 5.1 | Create `lib/struct/ai/ai_response_formatter.dart` | File with `AiResponseFormatter` class | ✅ |
| 5.2 | Implement `format(AiExecutionResult)` for transaction | "Added ₹1,200 expense to Groceries" | ✅ |
| 5.3 | Implement `format(AiExecutionResult)` for budget | "Created budget 'Food' with ₹15,000 monthly limit" | ✅ |
| 5.4 | Implement `format(AiExecutionResult)` for objective | "Created goal 'Vacation' — save ₹50,000" | ✅ |
| 5.5 | Implement `format(AiExecutionResult)` for spending query | "You spent ₹12,450 this month across 8 transactions. Top: Groceries ₹4,200, Dining ₹3,100" | ✅ |
| 5.6 | Implement `format(AiExecutionResult)` for budget remaining query | "Budget 'Food' has ₹8,500 remaining of ₹15,000 (57% used)" | ✅ |
| 5.7 | Implement `format(AiExecutionResult)` for net worth query | "Your net worth is ₹2,45,000 across 3 accounts" | ✅ |
| 5.8 | Implement `format(AiExecutionResult)` for navigate | "Opening Subscriptions..." | ✅ |
| 5.9 | Implement `format(AiExecutionResult)` for pay | "Marked Netflix subscription as paid" | ✅ |
| 5.10 | Implement `format(AiExecutionResult)` for error | "Something went wrong. Please try again." | ✅ |
| 5.11 | Implement `format(AiExecutionResult)` for unclear | "I didn't understand that. Could you rephrase?" | ✅ |
| 5.12 | Implement action button generation | `getViewAction(AiExecutionResult)` → label + route for [View Transaction], [View Budget], etc. | ✅ |
| 5.13 | Use `convertToMoney()` for all currency formatting | All amounts formatted with user's currency settings | ✅ |
| 5.14 | Write test: formatter produces correct strings for all 8 intent results | 8 test cases pass | ✅ |

**Phase 5 Exit Criteria:** All execution results produce natural language strings. Currency formatting respects user settings. Action buttons link to correct detail pages.

---

## Phase 6: Chat UI

| # | Task | Measurable Output | Status |
|---|------|-------------------|--------|
| 6.1 | Create `lib/widgets/aiAssistantChat.dart` | File with `AiAssistantChat` StatefulWidget | ✅ |
| 6.2 | Implement message list UI | `ListView.builder` with `AiChatBubble` for each message, auto-scrolls to bottom | ✅ |
| 6.3 | Implement user chat bubble | Right-aligned, primary color background, white text | ✅ |
| 6.4 | Implement AI chat bubble | Left-aligned, secondary container color, dark text | ✅ |
| 6.5 | Implement AI bubble with action button | [View Transaction] / [View Budget] tappable button inside AI bubble | ✅ |
| 6.6 | Implement typing indicator | Animated dots shown while LLM generates | ✅ |
| 6.7 | Implement text input bar | `TextInput` + send button, auto-focus, submit on Enter | ✅ |
| 6.8 | Implement suggestion chips | Horizontal `SelectChips` with: "add 500 coffee", "monthly budget 10k", "how much spent today?" | ✅ |
| 6.9 | Implement welcome message | First message in chat: greeting + suggestion chips | ✅ |
| 6.10 | Implement send message flow | On send: add user message → show typing → call `AiProvider.generateChatResponse()` → parse intent → execute → format response → add AI bubble | ✅ |
| 6.11 | Implement error state in chat | LLM error → AI bubble with error message + retry chip | ✅ |
| 6.12 | Implement model not downloaded state | Chat area shows download prompt with progress bar | ✅ |
| 6.13 | Implement model download progress | Stream progress 0→100% with cancel button | ✅ |
| 6.14 | Implement model initializing state | Loading spinner with "Initializing AI..." text | ✅ |
| 6.15 | Implement device incompatible state | Message: "Your device doesn't support on-device AI" | ✅ |
| 6.16 | Create `lib/widgets/aiAssistant.dart` | File with `AiAssistantSheet` widget | ✅ |
| 6.17 | Implement sheet wrapper | `openBottomSheet()` with `fullSnap: true`, contains `AiAssistantChat`, title "Cashew AI" | ✅ |
| 6.18 | Implement provider lifecycle | Initialize active provider on sheet open, dispose on close | ✅ |
| 6.19 | Test: chat UI renders on Android device | Sheet opens, input visible, welcome message shown | ✅ |
| 6.20 | Test: send message flow end-to-end | Type "add 500 coffee" → AI bubble shows "Added ₹500 expense to Dining" | ✅ |

**Phase 6 Exit Criteria:** Chat UI is fully functional. User can type commands and see AI responses. Model download works from within the sheet. All error states handled.

---

## Phase 7: App Integration

| # | Task | Measurable Output | Status |
|---|------|-------------------|--------|
| 7.1 | Modify `lib/widgets/navigationFramework.dart` | Add `AddThing(iconData: Icons.auto_awesome, title: "AI Assistant")` as first item in `AddMoreThingsPopup.build()` before Account | ⬜ |
| 7.2 | Modify `lib/pages/settingsPage.dart` | Add `SettingsContainerOpenPage(openPage: AiSettingsPage())` in "Tools & Extras" section | ⬜ |
| 7.3 | Create `lib/pages/aiSettingsPage.dart` | Full settings page with model management | ⬜ |
| 7.4 | Implement model status display | Shows: "Not downloaded" / "Downloading (42%)" / "Ready (2.4 GB)" | ⬜ |
| 7.5 | Implement fallback download button | Triggers `GemmaProvider.downloadModel()` with progress when fallback provider is selected | ⬜ |
| 7.6 | Implement delete model button | Removes model file, resets `aiModelDownloaded` setting | ⬜ |
| 7.7 | Implement confirm actions toggle | `SettingsContainerSwitch` for `aiConfirmActions` | ⬜ |
| 7.8 | Implement send context toggle | `SettingsContainerSwitch` for `aiSendContext` with privacy note | ⬜ |
| 7.9 | Implement clear chat history button | `SettingsContainer` that calls `AiChatHistory.clear()` | ⬜ |
| 7.10 | Implement device compatibility info | Shows device RAM, NPU support status | ⬜ |
| 7.11 | Test: FAB long-press shows AI Assistant option | Long-press FAB → bottom sheet shows "AI Assistant" as first item | ⬜ |
| 7.12 | Test: tapping AI Assistant opens chat sheet | AI Assistant → bottom sheet with chat UI opens | ⬜ |
| 7.13 | Test: settings page shows AI section | Settings → Tools & Extras → AI Assistant → settings page | ⬜ |
| 7.14 | Test: model download from settings | Download button starts download, progress updates, completes | ⬜ |

**Phase 7 Exit Criteria:** AI Assistant accessible from FAB long-press and settings. Model can be downloaded/deleted from settings page. All settings persist and work.

---

## Phase 8: End-to-End Testing & Polish

| # | Task | Measurable Output | Status |
|---|------|-------------------|--------|
| 8.1 | E2E test: "add 1200 rupees groceries" | Transaction created with amount=-1200, category=Groceries, wallet=default | ⬜ |
| 8.2 | E2E test: "received 5000 salary" | Transaction created with amount=+5000, isIncome=true, category=Income | ⬜ |
| 8.3 | E2E test: "Netflix 499 monthly subscription" | Transaction created with type=subscription, reoccurrence=monthly, amount=-499 | ⬜ |
| 8.4 | E2E test: "lent 5000 to John" | Transaction created with type=credit, amount=-5000, note="John" | ⬜ |
| 8.5 | E2E test: "monthly food budget of 15000" | Budget created with name="Food", amount=15000, reoccurrence=monthly | ⬜ |
| 8.6 | E2E test: "save 50000 for vacation" | Objective created with type=goal, name="Vacation", amount=50000 | ⬜ |
| 8.7 | E2E test: "how much did I spend this month" | Returns inline spending summary with category breakdown | ⬜ |
| 8.8 | E2E test: "how much left in food budget" | Returns remaining budget amount | ⬜ |
| 8.9 | E2E test: "what's my net worth" | Returns total across all wallets | ⬜ |
| 8.10 | E2E test: "show my subscriptions" | Navigates to subscriptions page | ⬜ |
| 8.11 | E2E test: "pay my Netflix subscription" | Marks Netflix upcoming/subscription as paid | ⬜ |
| 8.12 | E2E test: gibberish input → unclear intent | AI responds with "I didn't understand that" | ⬜ |
| 8.13 | E2E test: category not found | AI responds with "Should I create a category for X?" | ⬜ |
| 8.14 | E2E test: LLM timeout (30s) | Shows timeout error message | ⬜ |
| 8.15 | E2E test: model not downloaded flow | Opens sheet → shows download prompt → download → chat | ⬜ |
| 8.16 | E2E test: confirm before action (enabled) | Destructive action shows confirmation before executing | ⬜ |
| 8.17 | Performance test: LLM inference latency | Cold start < 5s, per-message response < 10s on mid-range device | ⬜ |
| 8.18 | Performance test: memory usage | Model loaded < 3GB RAM, no OOM on 6GB device | ⬜ |
| 8.19 | Polish: chat bubble animations | Fade-in for new messages | ⬜ |
| 8.20 | Polish: haptic feedback on send | Uses existing `savingHapticFeedback` setting | ⬜ |
| 8.21 | Polish: dark mode support | Chat bubbles themed correctly in light/dark/black themes | ⬜ |
| 8.22 | Polish: RTL layout support | Chat bubbles mirrored, input aligned correctly | ⬜ |

**Phase 8 Exit Criteria:** All 11 intent types work end-to-end on a real Android device. Error handling is robust. UI polished for light/dark/RTL. Performance acceptable on mid-range hardware.

---

## Phase Summary

| Phase | Description | Files | Est. Effort | Depends On |
|-------|-------------|-------|-------------|------------|
| 0 | Project Setup | 3 modified | 1-2h | None |
| 1 | Types & Abstraction | 3 new | 2-3h | Phase 0 |
| 2 | Gemini Nano Provider (Primary) | 1 new | 4-6h | Phase 1 |
| 2B | Gemma Provider (Fallback) | existing/new | 2-4h | Phase 2 |
| 3 | Context & Parser | 2 new | 4-6h | Phase 1 |
| 4 | Intent Executor | 1 new | 6-8h | Phase 1, 3 |
| 5 | Response Formatter | 1 new | 2-3h | Phase 1, 4 |
| 6 | Chat UI | 2 new | 6-8h | Phase 2, 2B, 4, 5 |
| 7 | App Integration | 1 new, 3 modified | 3-4h | Phase 6 |
| 8 | Testing & Polish | 0 new | 4-6h | Phase 7 |

**Total: 11 new files, 5 modified files, ~32-46 hours estimated effort**
