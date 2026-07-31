# AI Assist V1 — Spec

## Problem Statement

Adding a transaction in Cashew still means tapping through the add-transaction flow (amount, category, wallet, title, date). For quick everyday logging — “coffee 450”, “got paid 80k salary” — that friction is higher than it needs to be. Users want to describe a transaction in natural language and have the app propose the details, then confirm before anything is saved.

## Solution

An **AI Assist** chat in a bottom sheet. The user types natural language; OpenRouter returns a structured expense or income draft as an **editable preview card** inside the chat. The user can edit fields on the card, send follow-up messages to refine the draft, then confirm (creates the transaction, and a new category only if proposed) or discard. Chat persists across sheet closes, with a New chat control. Access: FAB long-press → existing extras popup → **AI Assist** as the first row. The user supplies their own OpenRouter API key in Settings.

## User Stories

1. As a Cashew user, I want to open AI Assist from the FAB long-press extras popup, so that I can log with natural language without learning a new navigation path.
2. As a Cashew user, I want AI Assist listed as the first row in the long-press extras popup, so that it is easy to find without removing existing shortcuts.
3. As a Cashew user, I want AI Assist to open in a bottom sheet chat, so that it feels lightweight and dismissible like other Cashew sheets.
4. As a Cashew user, I want to describe an expense in natural language, so that I do not have to fill the full add-transaction form for simple spending.
5. As a Cashew user, I want to describe income in natural language, so that salary and other inflows are as easy to log as expenses.
6. As a Cashew user, I want the AI to suggest amount, title, category, wallet, date, income/expense type, and optional note, so that the draft is ready to save with minimal edits.
7. As a Cashew user, I want missing dates to default to today, so that quick logs still get a sensible date.
8. As a Cashew user, I want missing wallet to default to my selected/default wallet, so that I rarely have to pick an account for routine logs.
9. As a Cashew user, I want an editable preview card in the chat after the AI processes my message, so that I can see exactly what will be created before it exists.
10. As a Cashew user, I want to edit amount, title, category, wallet, date, type, and note on the preview card, so that small mistakes do not require retyping the whole prompt.
11. As a Cashew user, I want to send another chat message to refine the current draft, so that I can say “make category Food” without manually hunting fields.
12. As a Cashew user, I want confirm and discard actions on the draft card, so that nothing is written to the ledger until I explicitly confirm.
13. As a Cashew user, I want confirm to create the transaction using Cashew’s normal persistence path, so that the new entry behaves like any other transaction (lists, budgets, sync expectations).
14. As a Cashew user, I want discard to remove or cancel only that draft, so that a bad suggestion does not pollute my chat or ledger.
15. As a Cashew user, after confirming, I want the card to show an “Added” success state and the sheet to stay open, so that I can log several transactions in one sitting and feel the win of each confirm.
16. As a Cashew user, I want the AI to match against my existing category names, so that suggestions land in categories I already use.
17. As a Cashew user, I want the AI to propose a new category when none fit, so that unusual spending is not forced into a wrong bucket.
18. As a Cashew user, I want a proposed new category to be created only when I confirm the draft, so that abandoned chats do not leave orphan categories.
19. As a Cashew user, I want new categories created with simple defaults (name + sensible default icon/color and income flag matching the draft), so that confirm stays one tap.
20. As a Cashew user, I want the model to receive my category names, wallet names with currencies, and default wallet each turn, so that suggestions are grounded in my data without sending full transaction history.
21. As a Cashew user, I want my chat session to persist when I close and reopen the sheet, so that I can resume mid-draft.
22. As a Cashew user, I want a New chat control at the top of the sheet, so that I can clear stale context and start clean.
23. As a Cashew user, I want to paste my OpenRouter API key in Settings, so that the feature works for me without the app shipping a shared secret.
24. As a Cashew user, I want a clear error if the API key is missing or invalid, so that I know what to fix instead of a silent failure.
25. As a Cashew user, I want the app to try `openai/gpt-oss-20b:free` first and fall back to `google/gemma-4-26b-a4b-it:free` when the primary fails or is rate-limited, so that free-tier flakiness is less painful.
26. As a Cashew user, I want structured JSON from the model (not free-form prose as the source of truth), so that the preview card is reliable.
27. As a Cashew user, I want unclear or incomplete prompts (e.g. no amount) to produce a helpful chat reply and/or an incomplete draft I can finish, so that the flow does not crash or invent nonsense silently.
28. As a Cashew user, I want transfers, subscriptions, debt/credit, budgets, goals, and spending queries out of this V1, so that the assistant stays focused and enjoyable for logging.
29. As a Cashew user, I want the normal short-press FAB add-transaction flow unchanged, so that AI Assist is optional power, not a replacement.
30. As a Cashew user, I want loading feedback while the model responds, so that the chat does not feel frozen.
31. As a developer/agent implementing this, I want the OpenRouter HTTP client injectable behind one seam, so that automated tests do not need a live API key.
32. As a developer/agent implementing this, I want confirm to go through existing `createOrUpdateCategory` / `createOrUpdateTransaction` (or equivalent existing APIs), so that V1 does not invent a parallel write path.

## Implementation Decisions

### Scope and product
- Fresh thin V1 only: natural-language **add expense / add income**, chat + editable draft card, confirm/discard.
- Do **not** reuse or continue the old multi-intent on-device assistant work; ignore that branch’s architecture for this feature.
- Out of V1 product surface: transfers, subscriptions, debt/credit, budgets, goals, queries, navigation intents, on-device models.

### Entry and UI
- FAB long-press continues to open the existing extras bottom sheet (`AddMoreThingsPopup`).
- Insert **AI Assist** as the **first** row/action in that popup; selecting it opens the AI Assist chat bottom sheet (can close or stack from the extras sheet in a way that feels natural).
- AI Assist UI: bottom sheet with:
  - Top bar including **New chat**
  - Scrollable chat transcript
  - Embedded **editable draft card** messages when the model returns a transaction draft
  - Text input to send messages / refinements
  - Loading state while waiting on OpenRouter
- Draft card fields (editable): amount, title, category (existing or “new: Name”), wallet, date, income vs expense, optional note.
- Card actions: confirm and discard.
- After confirm: card becomes a compact success (“Added”) state; sheet remains open.
- Discard: cancels that draft only (mark cancelled / remove interactive draft; do not delete chat history unnecessarily).

### Persistence
- Persist the current chat session (messages + any open/confirmed/cancelled draft states) locally so reopening the sheet resumes it.
- New chat clears the persisted session and starts empty.
- Confirmed transactions live in the normal ledger; persistence of chat is for UX continuity, not a second source of truth for money.

### OpenRouter / models
- User-provided OpenRouter API key stored in app settings (local), editable from Settings (Tools & Extras or similar).
- Primary model: `openai/gpt-oss-20b:free`
- Fallback model: `google/gemma-4-26b-a4b-it:free` on primary failure / rate limit / empty unusable response.
- Prefer OpenRouter **structured outputs** / `response_format` JSON schema when available; still defensively parse JSON from content if needed.
- Do **not** use `openrouter/free` auto-router for V1.

### Prompt / context contract (each model call)
Inject:
- Role: parse/refine a Cashew transaction draft from user text
- User’s **category names** (and enough identity to map back, e.g. name → categoryPk)
- User’s **wallet names + currencies** (and walletPk mapping)
- **Default / selected wallet**
- Current date (for “today” grounding)
- Current draft JSON when refining
- Recent chat turns needed for refinement (keep bounded)

Model response shape (conceptual):

```json
{
  "assistantMessage": "string",
  "draft": {
    "income": false,
    "amount": 450.0,
    "title": "Coffee",
    "categoryName": "Food",
    "createNewCategory": false,
    "newCategoryName": null,
    "walletName": "Cash",
    "date": "2026-07-31",
    "note": null
  }
}
```

- If `createNewCategory` is true, preview shows a proposed new category; **no DB write until confirm**.
- On confirm: if new category proposed → create category with simple defaults → create transaction linked to it; else resolve existing category by name/pk and create transaction.
- Use existing database APIs for category and transaction creation (same paths the rest of the app uses).

### Modules (logical; not file paths)
- **OpenRouter client** — HTTP chat completions; primary then fallback; injectable for tests.
- **Context builder** — loads categories/wallets/default wallet into prompt payload.
- **Assist session** — messages, drafts, persist/load/clear (New chat).
- **Draft apply / confirm** — maps draft → optional category create + transaction create; validates required fields before write.
- **AI Assist UI** — bottom sheet chat + draft card + settings key field + first-row entry in extras popup.

### Settings
- Store at least: OpenRouter API key; optionally last-used model id for debugging; persisted chat session blob.
- If key missing when user sends a message: show a clear prompt to add the key (deep-link or navigate to settings).

### Enjoyable UX bar (non-negotiable for V1)
- Chat-first, not a form wizard.
- Editable card + chat refinement both work.
- Confirm is the only ledger write for drafts.
- Success state after confirm; stay in sheet for another log.

## Testing Decisions

### What makes a good test
- Test **external behavior** at the highest useful seam: given user text + fake model responses + in-memory/fake category & wallet lists, assert resulting draft state and confirm side effects.
- Do **not** assert prompt string internals or widget tree trivia unless a UI regression is the point.
- Prefer unit/session tests over full Flutter widget tests for core logic (repo currently has almost no real test suite beyond a placeholder widget test).

### Primary seam (confirm with implementor / owner)
**One seam: `AiAssistSession` (name flexible) + injectable `OpenRouterClient`.**

- Production: real OpenRouter client.
- Tests: fake client returning canned JSON / errors / rate-limit then success on fallback.
- Confirm/discard tested by injecting a narrow **ledger writer** (or faking the existing DB layer) and asserting:
  - confirm with existing category → one transaction, zero categories created
  - confirm with `createNewCategory` → category then transaction
  - discard → no writes
  - refine message → draft fields update from second model response
  - primary failure → fallback model called
  - missing API key → no network call; clear error surface

Ideal: **one** behavioral seam for the feature; UI wires to it; DB writes go through existing create APIs behind a thin adapter if needed.

### Modules to test
- OpenRouter client (request model order / fallback) with HTTP mocked
- Session: persist/load/New chat, draft lifecycle (open → refined → confirmed/discarded)
- Confirm mapping: new category only on confirm; defaults for date/wallet
- JSON parse resilience (structured body vs embedded `{...}`)

### Prior art
- `budget/test/widget_test.dart` is a placeholder; little prior art. Establish focused unit tests next to the new assist module rather than expanding the empty widget smoke test.

### Live OpenRouter key for implementor agents
- **Not required** for automated implementation tests if the OpenRouter client is mocked at the seam above.
- **Optional** for manual smoke (“coffee 450” against real free models). If unavailable, ship with mocks + a short manual checklist for the human with a key.
- Never commit API keys; read from Settings / local env only for manual runs.

## Out of Scope

- Transfers, subscriptions, debt/credit, budgets, goals, spending queries, navigation commands
- On-device models (Gemini Nano, flutter_gemma, etc.)
- Multi-user / shared budget AI features
- Voice input, receipt OCR, image understanding
- Server-side proxy for OpenRouter (user key in-app only for this hobby V1)
- Full chat product (threads list, export, sync chat across devices)
- Replacing or removing the normal add-transaction page / short-press FAB
- Using `openrouter/free` auto-router
- Shipping a shared OpenRouter key inside the app binary

## Further Notes

- Hobby project: prefer thin enjoyable V1 over architecture that anticipates every intent.
- Free OpenRouter models can be rate-limited or temporarily unavailable; primary + fallback is intentional.
- Category identity: resolve by name carefully (case/ trim); if ambiguous, prefer explicit user edit on the card over silent wrong pick.
- New category defaults should follow existing Cashew category fields (name, income flag matching draft, order, default colour/icon) via the same creation APIs as the add-category flow, without opening that full page.
- Domain terms: **transaction**, **category**, **wallet**, **income** flag, FAB extras popup / `AddMoreThingsPopup`, bottom sheet — stay consistent with Cashew’s existing UI language.
- Seams note for owner: if you disagree that `AiAssistSession` + injectable OpenRouter client should be the single test seam, say so before implementation; fewer seams is better.
`)
