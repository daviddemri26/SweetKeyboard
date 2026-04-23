# SweetKeyboard

SweetKeyboard is an iPhone custom keyboard focused on fast daily typing, practical utility actions, and a local-first privacy model.

It combines a familiar English QWERTY layout with a permanent number row, a symbols layer designed for quick access, contextual return-key behavior, optional clipboard tools, and several quality-of-life flows that reduce layout switching while typing.

For a full functional breakdown, see [docs/FEATURES.md](docs/FEATURES.md).

## Commercial README

### Product Summary

SweetKeyboard is built for people who want a keyboard that feels familiar immediately, but removes a lot of small frictions from everyday typing:

- numbers are always visible
- common symbols are easy to reach
- the keyboard reacts to the current field
- clipboard tools are available when the user explicitly opts in
- everything stays local on device

The product direction is simple: keep the keyboard compact, fast, and trustworthy, while adding a few smart behaviors that save time right away.

### Core Value Proposition

SweetKeyboard helps users type faster without forcing them to learn a new layout.

- Permanent top number row for passwords, addresses, dates, and codes
- Fast symbols access with a dedicated symbols layer
- Emoji access from the symbols layer without adding a separate primary keyboard
- Contextual `@` shortcut in email fields
- Contextual action key that adapts to host app return-key traits
- Optional clipboard toolbar with copy, paste, and local history
- Local-only privacy model with no analytics, no sync, and no remote text processing

### What Feels Different

SweetKeyboard is intentionally optimized around practical typing flows rather than novelty.

- It reduces view switching by keeping numbers available at all times.
- It supports quick one-shot symbol entry by returning to letters automatically after a symbol when symbol lock is off.
- It can stay on symbols or emoji when symbol lock is enabled for repeated non-letter entry.
- It keeps emoji behind the symbols layer so the main keyboard stays compact and familiar.
- It exposes accent and punctuation variants through long press on supported keys.
- It follows host auto-capitalization intent in compatible fields instead of forcing a static Shift behavior.

### Main User-Facing Features

- English QWERTY typing layout
- Top number row: `1 2 3 4 5 6 7 8 9 0`
- Bottom-row period key always available in letters mode
- Direct `@` key in email fields
- Dedicated symbols keyboard
- Emoji sub-view available only from symbols mode
- Symbol lock toggle shared by symbols and emoji
- Automatic return from symbols to letters after one symbol when symbol lock is off
- Automatic return from emoji to letters after one emoji when symbol lock is off
- Left and right cursor movement keys in symbols mode
- Long-press accent variants for `a`, `c`, `e`, `i`, `n`, `o`, `u`, and `y`
- Long-press period variants: `…`, `:`, `•`, `@`, `!`, `?`, `,`
- Contextual action key for `return`, `search`, `go`, `next`, `send`, `done`, and related host return-key types
- Optional clipboard toolbar with `Copy`, `Paste`, `Clipboard`, and `Settings`
- Local clipboard history grid inside the keyboard
- In-keyboard settings panel for clipboard mode, auto-capitalization, and key haptics
- Optional key haptics

### Privacy Promise

SweetKeyboard is intentionally local-first.

- No analytics
- No cloud sync
- No network-based clipboard service
- No keystroke upload
- No remote inference or text processing

Clipboard history is stored locally in the shared App Group container used by the app and keyboard extension.

### Full Access Positioning

Basic typing works without Full Access.

Full Access is requested only for optional features that require system capability beyond basic text entry:

- `UIPasteboard` integration for copy and paste helpers
- shared settings and clipboard state between the containing app and the keyboard extension

If Full Access is disabled, SweetKeyboard automatically falls back to typing-only mode.

## Technical README

### Architecture

The project contains two Apple targets plus shared logic:

- `SweetKeyboard`: containing iOS app for setup, feature toggles, and privacy explanation
- `SweetKeyboardKeyboard`: custom keyboard extension built on `UIInputViewController`
- `Shared/`: shared models, persistence, layout rules, and typing-state logic used by both targets

### Current Technical Feature Set

- Shared settings persisted through `UserDefaults(suiteName:)`
- Shared clipboard history persisted in the App Group
- Shared capability status flag to confirm Full Access availability
- Keyboard layout generation through `KeyboardLayoutEngine`
- Contextual action-key resolution through host `UITextInputTraits`
- Auto-capitalization decision engine with explicit shift-state transitions
- Overlapping-touch coordination through `KeyboardPressSequenceCoordinator`
- Deferred keyboard rebuilds to avoid visual churn during fast interactions
- Long-press accent replacement logic through `AccentCatalog`
- Repeating backspace and repeating cursor controls
- Optional haptic feedback controller
### Recent Additions Reflected In This Documentation

The main behaviors added in the latest implementation pass are:

- contextual auto-capitalization with automatic, manual, and locked Shift states
- sequenced key handling so overlapping touches commit in press order
- emoji sub-view inside the symbols keyboard
- automatic return from non-letter layouts to letters after symbol or emoji insertion
- symbol lock persistence
- long-press period variants on the bottom row

These flows are covered by the current shared test suite and are documented in detail in [docs/FEATURES.md](docs/FEATURES.md).

### Typing Behavior Notes

#### Shift and Auto-Capitalization

SweetKeyboard maintains explicit shift states:

- `off`
- `autoSingle`
- `autoPersistent`
- `manualSingle`
- `manualLocked`

Behavior highlights:

- Empty sentence-style fields start with automatic Shift enabled
- Sentence terminators followed by a space re-enable one-shot Shift
- New lines re-enable one-shot Shift
- `.words` capitalization enables one-shot Shift after whitespace boundaries
- `.allCharacters` capitalization becomes persistent
- Email, URL, and username contexts suppress auto-capitalization
- Double-tapping Shift enables manual caps lock
- Tapping Shift while auto-capitalization is active suppresses the current automatic state until the text context changes

#### Symbols Flow

- The symbols keyboard contains three symbol rows plus a punctuation/action row
- The symbols keyboard bottom row includes `ABC`, an Emoji toggle, space, and the action key
- The emoji keyboard reuses the same bottom two rows and swaps the bottom-row toggle to `#+=`
- The emoji keyboard contains three fixed emoji rows for the current v1 implementation
- The punctuation row includes symbol lock, cursor left, cursor right, and backspace
- In compact mode, a gear key appears inline on the symbols and emoji punctuation row so settings stay reachable without the top toolbar
- With symbol lock off, inserting a symbol returns to the letters keyboard
- With symbol lock off, inserting an emoji also returns to the letters keyboard
- With symbol lock on, symbol or emoji insertion keeps the current non-letter keyboard open
- Space, backspace, cursor movement, and the primary action key do not force a return to letters
- Opening settings from symbols or emoji returns to the letters keyboard first

#### Long Press Variants

- Supported letters replace the row above them with accent variants after a hold
- Uppercase variants are shown when Shift is active
- Holding the bottom-row period key exposes quick punctuation shortcuts
- Clearing the accent state restores the default letter layout

### Clipboard Model

- Clipboard mode is user-controlled through shared settings
- The top action bar appears only when Full Access is available and clipboard mode is enabled
- `Copy` uses `selectedText` when the host exposes it
- `Paste` reads from `UIPasteboard.general`
- Clipboard history is local only
- History is stored newest first
- History keeps a maximum of 50 items
- History preserves the full copied text for each item
- Consecutive duplicate items are ignored
- Tapping a history item inserts its text and returns to keyboard mode

### Action Key

The bottom-right action key resolves from `UIReturnKeyType` exposed through `textDocumentProxy`.

Implemented mappings include:

- icon-style `Return`
- icon-style `Search`
- icon-style `Go`
- text labels for `Google`, `Join`, `Next`, `Route`, `Send`, `Yahoo`, `Done`, `Emergency`, and `Continue`

The extension intentionally mirrors the host field intent conservatively and falls back to the default return action when traits are incomplete or unavailable.

### Settings Surface

Settings are available in two places:

- in the containing app
- inside the keyboard extension

The current settings are:

- Auto-capitalization
- Clipboard toolbar
- Key haptics

Symbol lock is persisted as shared state and controlled directly from the symbols and emoji keyboard row.

### Privacy And Permissions

- Basic typing does not require Full Access
- Clipboard tools require Full Access
- Shared settings between app and extension rely on the App Group
- The current codebase is local-only and performs no network requests

### Platform Constraints

- Secure text fields do not allow third-party keyboards
- Some apps block custom keyboards entirely
- Host apps do not always expose enough `UITextInputTraits` information for perfect action-key matching
- Copy depends on the host exposing `selectedText` to the keyboard extension
- Real-world keyboard behavior should be validated on device, not only in Simulator

### Project Structure

```text
SweetKeyboard/
├── Shared/
│   ├── AccentCatalog.swift
│   ├── AutoCapitalizationResolver.swift
│   ├── ClipboardStore.swift
│   ├── KeyboardCapabilityStatusStore.swift
│   ├── KeyboardLayoutEngine.swift
│   ├── KeyboardPressSequenceCoordinator.swift
│   ├── KeyboardShiftStateMachine.swift
│   └── SharedKeyboardSettingsStore.swift
├── SweetKeyboard/
│   ├── ContentView.swift
│   ├── SweetKeyboardApp.swift
│   └── SweetKeyboard.entitlements
├── SweetKeyboardKeyboard/
│   ├── ActionKeyResolver.swift
│   ├── ClipboardPanelView.swift
│   ├── KeyboardActionBarView.swift
│   ├── KeyboardActionKeyRenderer.swift
│   ├── KeyboardFeedbackPresenter.swift
│   ├── KeyboardHapticFeedbackController.swift
│   ├── KeyboardKeyRepeatController.swift
│   ├── KeyboardLongPressController.swift
│   ├── KeyboardSettingsPanelView.swift
│   ├── KeyboardStyle.swift
│   ├── KeyboardViewController.swift
│   └── SweetKeyboardKeyboard.entitlements
├── SweetKeyboardTests/
└── docs/
```

### Requirements

- Xcode 16+
- A real iPhone for meaningful keyboard validation
- Apple signing configured for both targets
- Matching App Group capability on the app and extension

### Setup

1. Open `SweetKeyboard.xcodeproj` in Xcode.
2. Confirm signing for `SweetKeyboard` and `SweetKeyboardKeyboard`.
3. Ensure both targets use the same App Group:
   `group.com.daviddemri.SweetKeyboard`
4. Build and run the `SweetKeyboard` app on a device.
5. Add the keyboard from `Settings > General > Keyboard > Keyboards > Add New Keyboard`.
6. Enable `Allow Full Access` only if you want clipboard tools.

### Development Notes

- Core keyboard state and layout decisions live in `Shared/` so behavior can be tested without driving the full extension UI.
- `KeyboardLayoutEngine` owns row composition for letters, symbols, and emoji.
- `KeyboardPressSequenceCoordinator` owns overlapping-touch sequencing and layout-switch commit timing.
- `KeyboardViewController` is the main integration layer for rendering keys, applying themes, and dispatching typing actions.

### Testing

The shared behavior is covered by `SweetKeyboardTests`, including:

- layout generation
- symbol and emoji return rules
- overlapping-touch sequencing
- auto-capitalization decisions
- shared settings persistence
- clipboard normalization rules

Useful local commands:

```bash
xcodebuild build-for-testing \
  -project SweetKeyboard.xcodeproj \
  -scheme SweetKeyboard \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

```bash
xcodebuild test \
  -project SweetKeyboard.xcodeproj \
  -scheme SweetKeyboard \
  -destination 'id=<SIMULATOR-UDID>' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Replace `<SIMULATOR-UDID>` with an available iOS Simulator device from `xcrun simctl list devices available`.
