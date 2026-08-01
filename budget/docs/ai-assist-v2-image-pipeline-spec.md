# AI Assist V2 — Image Pipeline Spec

## Problem Statement

V1 handles natural-language text only. Users often have a receipt or product tag in hand and want to log the transaction without typing every field. They should be able to snap a photo (or pick from gallery), have the app read it, and create a draft — all within the existing AI Assist chat flow. Text-only input remains unchanged.

## Solution

Add an image-attachment affordance to the AI Assist chat input bar. When an image is attached, the pipeline becomes two-step:

1. **Read the image** using `nvidia/nemotron-nano-12b-v2-vl:free` (primary, document-intelligence-tuned) with `google/gemma-4-31b-it:free` as fallback — different provider (NVIDIA vs Google) for genuine resilience → raw OCR text
2. **Parse to draft** using the existing `openai/gpt-oss-20b:free` (with `google/gemma-4-26b-a4b-it:free` fallback) → structured `TransactionDraft` JSON

Text-only messages skip step 1 entirely and go straight to the existing single-step parse, same as V1.

The chat UI shows **friendly stage-change feedback** during the two-step process so latency feels acknowledged and purposeful, not like a frozen spinner.

When an image is processed, the OCR output is shown in full as a distinct chat message before the draft card appears, so the user can verify what was read from their receipt. The OCR text is displayed in a clearly labeled bubble (e.g. "Here's what I read:") and is **not truncated** — the full extracted text is visible.

## User Stories (additive to V1)

33. As a Cashew user, I want to attach a photo of a receipt or product tag from camera or gallery, so that I don't have to type out amounts and merchant names.
34. As a Cashew user, I want to see the attached image as a small thumbnail in my chat message, so that I can verify which photo I sent.
35. As a Cashew user, I want to remove an attached image before sending if I picked the wrong one, so that I don't send a confusing photo to the AI.
36. As a Cashew user, I want to combine an image with text (e.g. photo of receipt + "split this with John"), so that the AI can use both the image content and my extra instructions.
37. As a Cashew user, I want friendly loading feedback that tells me what the AI is doing (reading the image vs. creating the transaction), so that I know progress is being made during the two-step process.
38. As a Cashew user, I want text-only messages to work exactly as fast as V1, so that the image feature is purely additive overhead.
39. As a Cashew user, I want a clear error if the image couldn't be read, so that I know to retake the photo or type manually.
40. As a Cashew user, I want receipt images in my chat history to remain visible as thumbnails, so that I can scroll back and see what I logged.

## Showing OCR Output

After the vision model reads the image, the extracted text must be shown to the user as a full chat message — not hidden, not truncated. This serves two purposes:

1. **Transparency** — The user can verify the receipt was read correctly before a transaction is created from it
2. **Debugging** — If the draft is wrong, the user can see whether the OCR was bad or the parsing step misinterpreted good text

### OCR message bubble

```
┌──────────────────────────────────────────┐
│  📄  Here's what I read from your        │
│      receipt:                            │
│                                          │
│  Walmart Supercenter                     │
│  123 Main St                             │
│  2026-08-01                              │
│  ─────────────────────                   │
│  Milk 2%              $3.49             │
│  Bread                $2.29             │
│  Eggs (dozen)         $4.99             │
│  ─────────────────────                   │
│  Subtotal            $10.77             │
│  Tax                  $0.92             │
│  Total               $11.69             │
└──────────────────────────────────────────┘
```

- Role: `assistant`, but distinct from the draft-creating response
- Preceded by a small icon (📄 or `Icons.receipt_long_outlined`) and a brief label
- Uses a monospace or preformatted style so line alignment is preserved (critical for columnar receipt data)
- **No maxLines limit** — the full OCR output is always fully visible
- Scrolling: the message grows naturally; the chat list handles it
- This message appears **between** the loading stage and the draft card:
  1. User sends image
  2. "Reading your receipt…" (loading)
  3. OCR message appears (extracted text) ← NEW, fully visible
  4. "Creating transaction…" (loading) — brief, since parse is fast
  5. Draft card appears

The OCR message does **not** have a draft attached and cannot be confirmed/discarded. It is informational only.

## Loading / Stage-Change Feedback

This is the core UX concern for the two-step pipeline. Without explicit feedback, the user sees a single spinner for an uncomfortably long time and assumes the app is stuck.

### Friendly stage labels

| Internal step | Label shown to user | When |
|---|---|---|
| OCR in flight | **"Reading your receipt…"** | Image attached, waiting on Nemotron OCR |
| Parse in flight | **"Creating transaction…"** | OCR done, waiting on gpt-oss-20b to produce draft |
| Text-only parse | **"Creating transaction…"** | No image attached, existing single-step flow |

Only ever one label is visible at a time. The transition from "Reading your receipt…" → "Creating transaction…" is an explicit state change that gives the user a sense of progress.

### Loading bubble visual

Replace the existing bare `CircularProgressIndicator` bubble with:

```
┌──────────────────────────────────────┐
│  ◌  Reading your receipt…           │
└──────────────────────────────────────┘
```

```
┌──────────────────────────────────────┐
│  ◌  Creating transaction…           │
└──────────────────────────────────────┘
```

- The label text is right next to the spinner (not stacked below)
- Transition between stages: old bubble fades out, new one fades in (or simply updates the text inline — rapid transition, no need for a full animation)
- The spinner itself stays the same `CircularProgressIndicator(strokeWidth: 2)` as V1
- This should feel like a **natural substatus**, not a jarring replacement

### Implementation detail: state enum

```dart
enum LoadingStage {
  none,            // not loading
  readingImage,    // step 1: OCR in flight
  creatingDraft,   // step 2: parse in flight (or text-only single step)
}
```

The `_AiAssistChatState` holds a `LoadingStage` instead of a bare `bool _isLoading`. The loading bubble widget reads `_stage` and renders the appropriate label.

## Architecture: Two-Step Pipeline

```
┌─────────────────────────────────────────────────────┐
│                    USER INPUT                        │
│   Text: "groceries"  +  [Receipt Photo] 📷          │
└───────────────┬────────────────────┬────────────────┘
                │                    │
                ▼                    ▼
┌───────────────────────┐  ┌────────────────────────────────┐
│  STEP 1: OCR (Vision) │  │  CHAT UI                        │
│  nemotron-nano-12b    │  │                                 │
│  -v2-vl:free           │  │  User bubble:                   │
│                       │  │  ┌───────────────────────────┐  │
│  Input: base64 image  │  │  │ [thumbnail] "groceries"   │  │
│  Output: raw text     │  │  └───────────────────────────┘  │
│                       │  │                                 │
│  "Walmart Supercenter │  │  Loading:                        │
│   2026-08-01           │  │  "Reading your receipt…"        │
│   Milk 2%    $3.49    │  │  ↓ (stage change)               │
│   Bread      $2.29    │  │  "Creating transaction…"        │
│   Total:     $5.78"   │  │                                 │
└───────────┬───────────┘  └────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────┐
│  STEP 2: PARSE (Text) — EXISTING PIPELINE             │
│  gpt-oss-20b:free (primary)                          │
│  → fallback: gemma-4-26b-a4b-it:free                 │
│                                                       │
│  System prompt + OCR text + user typed text           │
│  → structured JSON transaction draft                 │
│                                                       │
│  The parse model receives the OCR output prepended    │
│  to any user-typed text, like:                        │
│  "Receipt contents:\n[OCR TEXT]\n\nUser note: groceries│
│   split with John"                                     │
└──────────────────────┬───────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│  SHOW DRAFT CARD + CONFIRM (existing flow, unchanged)│
└──────────────────────────────────────────────────────┘
```

### Model routing table

| Input | Step 1 (OCR) | Chat insertion | Step 2 (Parse) |
|-------|-------------|----------------|----------------|
| Text only | — skipped — | — | `gpt-oss-20b:free` → `gemma-4-26b-a4b-it:free` |
| Image + optional text | `nemotron-nano-12b-v2-vl:free` → `gemma-4-31b-it:free` | OCR text shown as assistant message | `gpt-oss-20b:free` → `gemma-4-26b-a4b-it:free` |

### Why these models

| Role | Model | Size | Why |
|------|-------|------|-----|
| OCR primary | `nvidia/nemotron-nano-12b-v2-vl:free` | 12B dense | Built for document intelligence, hybrid Transformer-Mamba, 128K max output |
| OCR fallback | `google/gemma-4-31b-it:free` | 30.7B dense | Different provider (Google), strongest available free vision model, 256K context |
| Parse primary | `openai/gpt-oss-20b:free` | 21B MoE | Fast text-only reasoning, JSON structured output |
| Parse fallback | `google/gemma-4-26b-a4b-it:free` | 25.2B MoE | Different provider, vision-capable but used text-only here for reliability |

Every step has a fallback from a **different provider** (NVIDIA↔Google, OpenAI↔Google), so a single provider outage can't kill the entire pipeline.

## Implementation Plan

### Files to change

#### 1. `ai_assist_models.dart` — Image support in data model

- Add `String? imageBase64` field to `ChatMessage` (stores a compressed thumbnail for chat display, not the full-resolution image)
- Add `bool get hasImage` convenience getter
- Update `toJson()` / `fromJson()` to round-trip `imageBase64`
- `AiAssistResponse` — unchanged

#### 2. `openrouter_client.dart` — OCR + parse pipeline

**New constants:**
```dart
static const _ocrPrimaryModel = 'nvidia/nemotron-nano-12b-v2-vl:free';
static const _ocrFallbackModel = 'google/gemma-4-31b-it:free';
static const _primaryModel = 'openai/gpt-oss-20b:free';     // unchanged
static const _fallbackModel = 'google/gemma-4-26b-a4b-it:free'; // unchanged
```

**New public method `ocrImage(String imageBase64)`:**

- Sends a POST to the same OpenRouter endpoint with:
  - Model: tries `_ocrPrimaryModel` first, falls back to `_ocrFallbackModel` on any failure (rate limit, 5xx, empty response, auth)
  - Auth errors (401/403) skip fallback and throw immediately — a bad key won't work on either provider
  - Messages: single user message with content as an array:
    ```json
    {
      "role": "user",
      "content": [
        {"type": "text", "text": "Read all text from this image. Return only the extracted text, no commentary."},
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}
      ]
    }
    ```
  - No `response_format` constraint (we want free text back, not JSON)
- Returns the raw `content` string from the model response
- If both models fail, throws `OpenRouterException`

**Modified `sendMessage()` signature:**
```dart
Future<AiAssistResponse> sendMessage({
  required String userMessage,
  required List<ChatMessage> history,
  required List<String> categoryNames,
  required Map<String, String> walletNamesWithCurrencies,
  required String defaultWalletName,
  required String currentDate,
  String? imageBase64,       // NEW
  TransactionDraft? currentDraft,
});
```

**Client exposes two public methods:**

`ocrImage(String imageBase64) → Future<String>`
- Calls OCR model (primary → fallback) as described above
- Returns the raw extracted text
- Called by the UI layer so the page can insert the OCR message before proceeding

`sendMessage(...)` — same signature as V1, but accepts `ocrText` instead of `imageBase64`:

```dart
Future<AiAssistResponse> sendMessage({
  required String userMessage,
  required List<ChatMessage> history,
  required List<String> categoryNames,
  required Map<String, String> walletNamesWithCurrencies,
  required String defaultWalletName,
  required String currentDate,
  String? ocrText,            // NEW — pre-extracted OCR text from page
  TransactionDraft? currentDraft,
});
```

**`sendMessage()` logic:**
```
if ocrText != null:
  combinedMessage = "Receipt contents:\n$ocrText\n\nUser message: $userMessage"
  parse combinedMessage as normal (primary → fallback)
else:
  proceed exactly as V1 (single call to primary → fallback)
```

**Orchestration (in `ai_assist_page.dart`):**
```
if image attached:
  1. ocrText = await client.ocrImage(imageBase64)    // primary → fallback
  2. insert OCR message into chat (assistant, informational)
  3. set loadingStage = creatingDraft
  4. response = await client.sendMessage(ocrText: ocrText, ...)
else:
  response = await client.sendMessage(...)  // text only, no ocrText
```

#### 3. `ai_assist_page.dart` — UI for image attach + loading stages

**State changes:**
- Replace `bool _isLoading` with `LoadingStage _loadingStage = LoadingStage.none`
- Add `String? _attachedImageBase64` — the image the user has selected but not yet sent
- Add `String? _attachedImagePath` — file path (for display from file, since base64 in memory could be large; we keep a small display copy)

**Image picker integration (reuses existing `image_picker` dependency):**
- Add a camera/gallery button (paperclip icon, `Icons.attach_file_rounded`) to the left of the text field in `_buildInputBar`
- On tap: show a bottom sheet with two options — "Camera" and "Gallery" (matching existing Cashew patterns)
- Selected image → store compressed base64 (max 2048px longest edge, JPEG quality 80%) in `_attachedImageBase64`, show thumbnail chip above input bar

**Thumbnail chip (pre-send preview):**
```
┌──────────────────────────────────────────┐
│  ┌──────────┐                            │
│  │ thumbnail │  groceries                 │  ← text field
│  │   [✕]    │                             │
│  └──────────┘                             │
│                                    [📎] [➤]│
└──────────────────────────────────────────┘
```
- Thumbnail appears above the input inside the input bar area
- Small `✕` overlay in corner to remove
- Tapping the thumbnail does nothing (no full-screen preview for V2; avoid scope creep)

**User message bubble with image:**
```
┌─────────────────────────────────┐
│  ┌──────────┐                   │
│  │ thumbnail │                  │
│  └──────────┘                   │
│  "groceries"                    │
└─────────────────────────────────┘
```
- Thumbnail is 80×80dp, rounded corners 8dp
- Sits above the text content
- Tapping the thumbnail opens the full image (use existing Cashew image viewers if any, else a simple dialog)

**Loading bubble with stage label:**
```
┌──────────────────────────────────────┐
│  ◌  Reading your receipt…           │
└──────────────────────────────────────┘
```
- Row: `SizedBox(20×20, CircularProgressIndicator(strokeWidth: 2))` + `SizedBox(width: 8)` + `TextFont("Reading your receipt…", fontSize: 13)`
- When stage transitions to `creatingDraft`, update the text to "Creating transaction…"
- Transition should feel like a smooth inline update — a quick opacity tween on the text portion is plenty

**`_sendMessage()` updated logic:**
```
1. Capture text + imageBase64 from state
2. Clear input field + clear attached image
3. Add user ChatMessage with role:'user', content:text, imageBase64:thumbnail
4. If image attached:
   a. Set _loadingStage = LoadingStage.readingImage
   b. Wait for OCR result (ocrText)
   c. Add OCR ChatMessage with role:'assistant', content:ocrText (no draft, informational only)
   d. Set _loadingStage = LoadingStage.creatingDraft
5. Call client.sendMessage(userMessage: textWithOcr, ...)  // ocrText prepended if present
6. On response, add assistant ChatMessage with draft as before
7. Set _loadingStage = LoadingStage.none
```

Note: The client's `sendMessage()` still handles OCR internally (for fallback robustness), but the page now orchestrates the two stages explicitly so it can insert the OCR message in between. The client exposes a separate `ocrImage()` method that the page calls, then the page passes the OCR text into `sendMessage()` as a combined message.

#### 4. `ai_assist_session.dart` — No changes

Inherits `imageBase64` support automatically from `ChatMessage` serialization changes.

#### 5. `ai_assist_confirm.dart` — No changes

#### 6. `ai_assist_test.dart` — Additional tests

| Test | Description |
|------|-------------|
| `ChatMessage` with image round-trip | Serialize → deserialize preserves `imageBase64` |
| `ChatMessage` without image | `hasImage` is false, `imageBase64` is null |
| OCR request format | Verify request body has `content` as array with `image_url` type |
| OCR returns raw text | Verify extracted text is returned from `ocrImage()` |
| OCR message inserted in chat | After OCR completes, an informational assistant message with the full extracted text appears before the draft |
| OCR primary succeeds | Nemotron 12B is called, fallback is not |
| OCR primary fails → fallback used | Nemotron fails (500), gemma-4-31b is called and succeeds |
| OCR both fail → error thrown | Both OCR models fail, no parse call made, no OCR message added |
| OCR auth error skips fallback | 401 auth error does not retry with fallback (bad key won't help) |
| Two-step: image path | Full integration: image → OCR call(s) → OCR message → parse call(s) → draft |
| Single-step: text only | No OCR call when `imageBase64` is null, no OCR message inserted |
| Loading stages | `loadingStage` transitions: none → readingImage → (OCR msg shown) → creatingDraft → none |
| Fallback on parse failure | Step 2 falls back to gemma-4-26b when primary fails (existing behavior, unchanged) |

#### 7. `pubspec.yaml` — No changes (already has `image_picker: ^1.1.2`, `http: ^1.2.1`)

### Image compression / size management

Full-resolution photos from modern phone cameras are 4–12 MB. Sending that as base64 to an API is unreasonable. Strategy:

1. **At pick time:** Use `image_picker` with `imageQuality: 80` and `maxWidth: 2048`, `maxHeight: 2048` to reduce before loading into memory
2. **For API send (OCR):** The 2048px image is base64-encoded and sent directly. At 2048px JPEG quality 80, a typical receipt photo is ~200–400 KB base64 (~150–300 KB binary). This is well within OpenRouter limits.
3. **For chat thumbnail display:** Decode the image bytes, resize to 160×160px, re-encode as JPEG quality 60, store as base64 in the `ChatMessage`. This yields ~3–6 KB per message stored in SharedPreferences — negligible.
4. **For chat history to parse model:** Image data is **never** included in the history passed to the parse step. The OCR text replaces it. This prevents context window bloat in multi-turn conversations.

### Error handling

| Failure | User sees | Technical |
|---------|-----------|-----------|
| Image picker cancelled | Nothing happens, return to chat | `XFile` is null, do nothing |
| Image too large / format unsupported | "This image couldn't be used. Try a different photo." | Catch at compression time |
| OCR primary fails, fallback succeeds | Nothing visible to user — slightly slower OCR step, then OCR message appears as normal | Nemotron fails → gemma-4-31b handles it transparently |
| OCR both models fail | "Couldn't read your receipt. Try again or type the details." | Both OCR models exhausted, no OCR message, `_loadingStage` reset to none, error bubble shown |
| OCR auth error (401/403) | "Invalid API key. Check your OpenRouter key in Settings." | Does NOT fall back — bad key affects all models equally |
| OCR returns empty text | "No text found in the image. Try a clearer photo." | Validate `ocrText.trim().isNotEmpty` before proceeding, no OCR message added |
| Parse fails (same as V1) | Existing V1 error handling | Fallback to gemma-4-26b, then error if both fail |

### Chat history behavior (important design decision)

- User messages store a **small thumbnail** (max 160×160px, ~3–6 KB base64) in `imageBase64` for chat display
- When sending subsequent follow-up messages, **image data is never re-sent** to the parse model. Only the OCR text from step 1 is threaded into the message content.
- If the user sends a new image in a later turn, step 1 runs again on the new image only.
- This keeps the parse model's context window clean and prevents accumulated base64 bloat.

## Text Clipping Fix (V2 scope)

Currently, both user and assistant message bubbles clip text to 1 line, making it impossible to read multi-line messages or OCR output. This must be fixed in V2.

### Current behavior (broken)

```dart
// _buildMessageBubble — both user and assistant:
child: TextFont(
  text: message.content,
  fontSize: 14,
  // maxLines is NOT set — defaults to 1, clipping everything
),
```

Messages longer than one line are silently cut off — the user sees only the first line of any response. This is especially bad for:
- Long OCR output (multi-line receipt text)
- Multi-sentence assistant messages
- User messages with instructions spanning multiple lines

### Fix

- Both user and assistant text bubbles: set `maxLines: null` (or a high value like `maxLines: 20`) so the full message is always visible
- The `BoxConstraints(maxWidth: 320)` stays to constrain width; text wraps naturally
- For the OCR message specifically: use a monospace-adjacent style (or at minimum preserve whitespace) so columnar receipt data aligns
- The chat `ListView` handles scrolling; long messages just make the bubble taller

### Where

- `_buildMessageBubble()` — user branch: add `maxLines: null` to the `TextFont`
- `_buildMessageBubble()` — assistant branch: add `maxLines: null` to the `TextFont`
- New OCR message bubble: same `maxLines: null` treatment

## What does NOT change from V1

- Text-only input path: zero overhead added, same latency
- API key management: same OpenRouter key in Settings
- Draft card display, editing, confirm/discard: identical
- Session persistence: same SharedPreferences mechanism (`ChatMessage` gains `imageBase64`, which serializes automatically)
- New chat: clears images along with text history
- Category resolution, wallet matching, date defaults: unchanged
- Fallback logic for parse step: unchanged
- Both OCR and parse steps have independent primary→fallback chains, each across different providers

## Out of Scope (for V2)

- Multi-image per message (one image at a time only)
- PDF / multi-page receipt support
- Barcode / QR code scanning for product lookup
- Auto-cropping / perspective correction of receipt photos
- OCR confidence scores or editing extracted text before parse
- Voice input + image combination
- Saving original images to device / Google Drive (just OCR, image discarded after use)
- Full-screen image viewer from chat (tap thumbnail does nothing or opens system viewer)
- Image in assistant messages (assistant never sends images)
- On-device OCR (Google ML Kit, etc.) — cloud-only for V2
- Threading image through to subsequent refinement messages
