# SweetKeyboard Feature Reference

This document is the detailed functional reference for the current codebase. It is meant to support README updates, release notes, product copy, QA passes, and future design iterations.

## Feature Audit

### Core Keyboard

- English QWERTY letter layout
- Permanent top number row
- Shift, backspace, space, symbols toggle, and contextual primary action key
- Bottom-row period key always available in letters mode
- Contextual `@` shortcut in email fields

### Symbols Keyboard

- Three dedicated symbol rows
- Native-style symbols grouped together on one symbols page
- Emoji sub-view available only from symbols mode
- Punctuation row with `.`, `,`, `?`, `!`, and `'`
- Cursor left and cursor right keys
- Optional horizontal swipe cursor movement across the keyboard
- Faster cursor movement at higher horizontal swipe velocities
- Backspace in symbols mode
- `ABC` key to return to letters
- Emoji toggle key between `ABC` and space in symbols mode
- `#+=` key to return from emoji to symbols
- Symbol lock toggle
- Inline settings key in compact mode

### Clipboard And Toolbar

- Optional top action bar in clipboard mode
- `Copy`
- `Import`
- `Clipboard`
- `Settings`
- `Hide Keyboard`
- Local clipboard history grid
- Pinned clipboard favorites shown before unpinned history
- Manual system clipboard import button for available plain text

### In-Keyboard Settings

- Auto-capitalization toggle
- Clipboard toolbar toggle
- Open clipboard after copy toggle
- Swipe cursor toggle
- Key haptics toggle

### Containing App

- Keyboard setup instructions
- Feature toggles mirrored from shared settings
- Marketing-oriented Features tab focused on differentiators
- Privacy explanation
- Platform limitation notes
- Adaptive light and dark app chrome that follows the phone appearance

## Newly Added Behaviors

These are the main recent features that required the documentation refresh.

### Contextual Auto-Capitalization

Implemented through `AutoCapitalizationResolver` and `KeyboardShiftStateMachine`.

Current behavior:

- Empty compatible fields start with Shift active
- Sentence mode re-enables one-shot Shift after `.`, `!`, or `?` followed by space
- New lines re-enable one-shot Shift
- Word mode re-enables one-shot Shift after whitespace boundaries
- All-characters mode becomes persistent Shift
- Email, URL, and username-style inputs disable auto-capitalization
- Selection disables auto-capitalization decisions until the selection is cleared

Shift states used internally:

- `off`
- `autoSingle`
- `autoPersistent`
- `manualSingle`
- `manualLocked`

User-visible implications:

- A single manual Shift press affects one letter
- Double-tap Shift enables caps lock
- Tapping Shift while auto-capitalization is active turns the automatic behavior off for the current context

### Sequenced Key Handling

Implemented through `KeyboardPressSequenceCoordinator`.

Problem addressed:

- Fast typists can overlap touches between keys before the previous finger is fully lifted.

Current behavior:

- The pending key commits when the next key touch begins
- Commit order follows press order rather than release order
- Shift, layout switches, and the primary action key wait for release unless another key touch commits them first
- Cancelled touches do not commit
- Keyboard rebuilds can be deferred until the interaction completes

Result:

- More stable behavior during fast typing
- Fewer accidental lost presses when moving quickly across the keyboard
- Less UI churn when switching layout or shift state mid-gesture

### Automatic Return From Non-Letter Layouts

Implemented through `shouldReturnToLetterKeyboardAfterNonLetterAction`.

Current behavior:

- Entering one symbol returns to letters when symbol lock is off
- Entering one symbol or emoji stays on the current non-letter layout when symbol lock is on
- Entering one emoji returns to letters when symbol lock is off
- Space does not force a return to letters
- Backspace does not force a return to letters
- Cursor movement does not force a return to letters
- Primary action does not force a return to letters
- Opening settings from symbols or emoji returns to letters first

Design intent:

- Make one-off symbol entry faster without breaking repeated symbol entry workflows

### Cursor Movement

Implemented through cursor keys in the symbols layout and a keyboard-wide `UIPanGestureRecognizer`.

Current behavior:

- The symbols punctuation row includes dedicated left and right cursor keys
- Holding a cursor key repeats movement
- Optional swipe cursor movement is enabled by shared settings
- Horizontal swipes can begin anywhere across the keyboard rows
- Faster horizontal swipes use a lower points-per-character threshold
- Very fast swipes can move more characters per update than normal-speed swipes
- Vertical or weakly horizontal pans are ignored so normal typing remains stable

Design intent:

- Make precise edits possible without relying only on the iOS magnifier
- Make long horizontal cursor moves feel proportional to swipe speed

### Symbol Lock

Implemented through shared settings storage and the symbols row lock key.

Current behavior:

- Symbol lock state persists through shared settings
- The symbols lock icon changes between open and closed lock states
- The same lock state is shared by symbols and emoji
- When enabled, repeated symbol and emoji entry does not bounce back to letters

### Long-Press Accent And Period Variants

Implemented through `AccentCatalog`, `KeyboardLongPressController`, and dynamic layout replacement.

Supported letter long presses:

- `a` -> `à â ä á æ ã å ā`
- `c` -> `ç ć č`
- `e` -> `é è ê ë ē`
- `i` -> `î ï í ì ī`
- `n` -> `ñ ń ň`
- `o` -> `ô ö ó ò œ õ ø ō`
- `u` -> `ù û ü ú ū`
- `y` -> `ÿ ý`

Supported period long press:

- `.` -> `… : • @ ! ? ,`

Current behavior:

- Holding a supported letter replaces the row above it with variants
- Holding the bottom-row period replaces the bottom letter row with punctuation shortcuts
- Shift-active letters show uppercase variants
- Releasing or completing the interaction restores the default layout

## Field-Aware Behavior

### Email Fields

Detected through `keyboardType == .emailAddress` or matching `textContentType`.

Current behavior:

- `@` appears on the bottom letter row
- Auto-capitalization is disabled

### Contextual Action Key

Implemented through `ActionKeyResolver`.

Resolved host return-key styles:

- `default`
- `search`
- `go`
- `google`
- `join`
- `next`
- `route`
- `send`
- `yahoo`
- `done`
- `emergencyCall`
- `continue`

Current behavior:

- Uses icon presentation for default return and search
- Uses text presentation for most named actions
- Falls back conservatively when traits are missing

## Clipboard Model

Implemented through `ClipboardStore` and the keyboard toolbar.

Storage rules:

- Local only
- Shared through the App Group
- Maximum 50 items
- Full copied text is preserved per item
- Copied text is handled as exact plain text; the pasteboard write is verified byte-for-byte before history is updated
- Consecutive duplicates are ignored
- Pinned favorites appear before unpinned history
- Pinned favorites are ordered by newest pin first
- Unpinned history appears newest first

Interaction rules:

- `Copy` saves the selected text if the host exposes it, or the selected text inside an open clipboard detail view
- `Copy` can optionally open clipboard history automatically after a successful save
- The top toolbar shows an import button when iOS reports plain text is available in the system pasteboard
- Tapping the import button saves the current system pasteboard text into local history
- Selecting a history item inserts it directly into the current field
- Long-pressing a history item opens a full-text detail view with Back and Paste actions; selected detail text can be copied into history from the top action bar
- Detail view actions can pin or unpin an item
- Clipboard mode depends on Full Access

Favorite rules:

- Pinned items are still plain clipboard history items
- Pin state is persisted with the item
- Legacy clipboard items without pin metadata load as unpinned
- Pinning an item does not upload, sync, or transform the stored text

## Settings Model

Persisted through `SharedKeyboardSettingsStore`.

Shared settings currently stored:

- `clipboardModeEnabled`
- `keyHapticsEnabled`
- `autoCapitalizationEnabled`
- `symbolLockEnabled`
- `openClipboardAfterCopyEnabled`
- `cursorSwipeEnabled`

Default values:

- Clipboard mode off
- Key haptics off
- Auto-capitalization on
- Symbol lock off
- Open clipboard after copy off
- Swipe cursor on

## Privacy And Permissions

### Without Full Access

- Basic typing works
- Symbols and emoji work
- Action key works
- Auto-capitalization works
- Accent variants work
- Clipboard toolbar is unavailable

### With Full Access

- Clipboard toolbar can be enabled
- Clipboard import button appears only when system pasteboard text is available
- Shared app-to-keyboard settings stay synchronized
- Clipboard history and system pasteboard features work

Current privacy position:

- No analytics
- No cloud sync
- No remote services
- No typed text upload

## Containing App Interface

The app target is a setup and product-education surface, separate from the keyboard extension UI.

Current tabs:

- Home: setup steps for adding the keyboard and enabling Full Access when needed
- Settings: shared toggles for clipboard mode, copy behavior, auto-capitalization, swipe cursor, and haptics
- Features: marketing-oriented feature page focused on SweetKeyboard's differentiators
- Info: privacy, Full Access explanation, iOS limits, and app version

Features tab hierarchy:

- Always-on number row on the main letter keyboard
- Native-style symbols grouped on one page
- Left and right cursor keys
- Keyboard-wide swipe cursor movement with speed-aware travel
- Clipboard history with pinned favorites and one-tap paste
- Secondary compact coverage for auto-capitalization, action key, email shortcut, emoji, symbol lock, long-press shortcuts, haptics, shared settings, and local privacy

Appearance:

- The app follows the phone's light or dark setting automatically
- Home, Settings, and Info keep their current content structure
- Shared cards, badges, text colors, borders, and background colors use adaptive SwiftUI colors

## Test Coverage

The current test suite explicitly covers the newest functional work:

- accent layout replacement rules
- period long-press variants
- auto-capitalization decisions
- shift-state transitions
- symbol lock persistence
- symbol-to-letter return rules
- overlapping-touch sequencing
- shared settings backward compatibility
- clipboard history preservation and item-cap rules
- clipboard pinning and ordering rules

## Platform Constraints

- Secure text fields do not allow third-party keyboards
- Some apps block custom keyboards altogether
- Host apps do not always expose enough trait information for perfect return-key matching
- Copy depends on the host exposing plain selected text to the extension
- The keyboard extension API does not expose selected text attributes, so rich styling and list formatting are out of scope for copy/paste

## Suggested Positioning For Future Copy

- "Fast typing without layout friction"
- "Numbers always visible"
- "Symbols in one place"
- "Cursor movement without the magnifier"
- "Favorites for the snippets you paste again"
- "Clipboard tools only if you opt in"
- "Private by default, local by design"
