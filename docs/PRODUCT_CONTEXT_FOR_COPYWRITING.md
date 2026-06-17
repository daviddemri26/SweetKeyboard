# SweetKeyboard Product Context For Copywriting

This document is a standalone product brief for an agent or writer who does not have access to the source code. It summarizes the current SweetKeyboard application, its implemented features, its privacy model, and the safest positioning for App Store, commercial, technical, and promotional copy.

## Product Snapshot

- Product name: SweetKeyboard
- Product type: iOS custom keyboard app with a containing setup app and a keyboard extension
- Current primary language/layout: English QWERTY
- Privacy policy URL: https://lafayette-consulting.us/sweetkeyboard/privacypolicy/
- Core positioning: fast everyday typing with fewer layout switches, practical editing controls, optional local clipboard tools, and a local-first privacy model
- Main constraint: SweetKeyboard is an iOS third-party keyboard, so it must respect iOS keyboard-extension limitations, including secure-field restrictions and Full Access rules

## One-Sentence Product Description

SweetKeyboard is a local-first iOS keyboard that keeps numbers, symbols, cursor movement, and reusable clipboard snippets close to the typing flow without forcing users to learn an unfamiliar layout.

## Priority 0: Core Value Proposition

These are the most important product points and should lead App Store and marketing copy.

### 1. Familiar QWERTY Typing With Less Layout Friction

SweetKeyboard keeps the main typing experience familiar while reducing common switching moments.

- English QWERTY letter layout
- Permanent top number row from `1` to `0`
- Bottom-row period key always available in letters mode
- Shift, backspace, space, symbols toggle, and contextual action key
- Contextual `@` shortcut in email fields

Why it matters:

- Users can type dates, codes, addresses, numbers, passwords, and punctuation with fewer keyboard switches.
- The keyboard feels familiar immediately instead of requiring a new typing system.

Safe copy angle:

- "Numbers stay visible while you type."
- "A familiar keyboard with fewer interruptions."
- "Built for everyday typing, codes, addresses, and quick edits."

### 2. Symbols In One Place

SweetKeyboard has a dedicated symbols layout designed to avoid deep symbol switching.

- Three dedicated symbol rows
- Native-style symbols grouped together on one symbols page
- Punctuation row with `.`, `,`, `?`, `!`, and `'`
- `ABC` key to return to letters
- Emoji sub-view available from symbols mode
- `#+=` key to return from emoji to symbols
- Symbol lock toggle for repeated symbol or emoji entry

Why it matters:

- One-off symbol entry is faster.
- Repeated symbol or emoji entry is possible without bouncing back to letters every time.

Safe copy angle:

- "Symbols are grouped on one clean page."
- "Tap one symbol and return to letters, or lock symbols when you need more."

### 3. Cursor Movement Without Fighting The Magnifier

SweetKeyboard gives users two ways to move through text.

- Dedicated left and right cursor keys in symbols mode
- Repeating cursor movement when holding cursor keys
- Optional horizontal swipe cursor movement across the keyboard
- Faster horizontal swipes move the cursor farther

Why it matters:

- Precise edits are easier, especially in short fields, messages, codes, and forms.
- Users are not limited to the iOS text magnifier.

Safe copy angle:

- "Move the cursor with arrow keys or a horizontal swipe."
- "Speed-aware cursor swiping helps long edits feel quicker."

### 4. Local-First Privacy

Privacy is a central product value, not a secondary note.

- No analytics
- No advertising SDKs
- No tracking SDKs
- No cloud sync
- No remote text processing
- No keystroke upload
- SweetKeyboard Clipboard data stays local on device
- Native iPhone Clipboard text is read only after a user taps a native clipboard action inside the keyboard

Why it matters:

- The app can be positioned as predictable, transparent, and local by design.
- This is especially important because keyboard apps naturally raise privacy concerns.

Safe copy angle:

- "Private by default, local by design."
- "No analytics, no cloud sync, no remote text processing."
- "Clipboard tools are optional and user-triggered."

## Priority 1: Daily Workflow Differentiators

These features should appear in longer App Store descriptions, screenshots, feature pages, and onboarding copy.

### 5. Context-Aware Typing

SweetKeyboard adapts to the active text field where iOS exposes enough context.

- Auto-capitalization can enable Shift at the start of compatible fields
- Sentence terminators followed by space can re-enable one-shot Shift
- New lines can re-enable one-shot Shift
- Word-mode capitalization can re-enable Shift after whitespace
- All-characters capitalization becomes persistent Shift
- Email, URL, and username-style contexts suppress auto-capitalization
- Selection disables auto-capitalization decisions until the selection clears
- Contextual action key can reflect host actions such as Return, Search, Go, Next, Send, Done, Continue, and related return-key types

Why it matters:

- The keyboard feels more native because it responds to field intent.
- Email fields can show a direct `@` key and disable unwanted capitalization.

Safe copy angle:

- "Adapts to the field you are typing in."
- "Return can become Search, Go, Next, Send, or Done when supported by the app."

### 6. Long-Press Shortcuts

SweetKeyboard includes long-press shortcuts for accent and punctuation variants.

Supported letter long presses:

- `a`: `à`, `â`, `ä`, `á`, `æ`, `ã`, `å`, `ā`
- `c`: `ć`, `ç`, `č`
- `e`: `è`, `é`, `ê`, `ë`, `ē`
- `i`: `í`, `ì`, `ī`, `î`, `ï`
- `n`: `ñ`, `ń`, `ň`
- `o`: `ó`, `ò`, `õ`, `ø`, `ō`, `œ`, `ô`, `ö`
- `u`: `û`, `ü`, `ú`, `ù`, `ū`
- `y`: `ÿ`, `ý`

Supported period long press:

- `.`, `…`, `:`, `•`, `@`, `!`, `?`, `,`

Why it matters:

- Common accents and punctuation remain available without adding visual clutter to the main keyboard.

Safe copy angle:

- "Hold supported keys for accents and quick punctuation."

### 7. Fast Typing Stability

SweetKeyboard includes internal handling for overlapping key touches.

- Fast overlapping touches commit in press order rather than release order
- Cancelled touches do not commit
- Layout rebuilds can be deferred during active interaction
- Shift, layout switches, and action keys are handled conservatively during fast presses

Why it matters:

- Fast typing is more stable.
- Fewer intended key presses are lost when fingers overlap during quick input.

Safe copy angle:

- Use this as technical/product support, not as a primary consumer promise.
- Better wording: "Designed for stable everyday typing, even when you move quickly."

## Priority 2: Optional Clipboard And Full Access Features

Clipboard tools are powerful, but copy must be precise because they depend on iOS Full Access and host-app behavior.

### 8. Optional SweetKeyboard Clipboard

SweetKeyboard includes a local clipboard grid inside the keyboard when clipboard mode is enabled and Full Access is available.

- Local SweetKeyboard Clipboard grid
- Maximum 50 saved items
- Full copied text preserved per item
- Consecutive duplicate items ignored
- Unpinned history appears newest first
- Pinned favorites appear before unpinned history
- Pinned favorites are ordered by newest pin first
- Tap a saved item to paste it into the current field
- Long-press a saved item to open a detail view
- Detail view includes Back, Paste, Pin/Unpin, and Delete actions
- Selected text inside a clipboard detail view can be copied back into history

Why it matters:

- Users can keep reusable snippets close to the keyboard.
- Pinned favorites make repeated text easier to find.

Safe copy angle:

- "Save and reuse local text snippets."
- "Pin favorites so important snippets stay at the top."
- "Paste saved text with one tap."

### 9. Native iPhone Clipboard Actions

SweetKeyboard can expose user-triggered native clipboard buttons when iOS reports plain text is available.

Configurable actions:

- Import and Paste: imports native iPhone Clipboard text into SweetKeyboard Clipboard and pastes it into the active field
- Just Import: saves native iPhone Clipboard text into SweetKeyboard Clipboard
- Just Paste: pastes native iPhone Clipboard text into the active field without saving it

Behavior:

- Buttons are shown only when native iPhone Clipboard plain text is available
- Availability is checked while the keyboard is open
- The user chooses which native clipboard buttons appear

Why it matters:

- The user stays in the typing flow after copying text from outside the keyboard.

Safe copy angle:

- "Choose how SweetKeyboard handles text copied to the native iPhone Clipboard."
- "Import, paste, or do both after a user action."

### 10. Clipboard Toolbar

When clipboard mode and Full Access are available, the keyboard can show a top toolbar.

Toolbar actions:

- Copy
- Clear Text Field
- Native iPhone Clipboard buttons
- Clipboard
- Settings
- Hide Keyboard

Why it matters:

- Utility actions are accessible without leaving the active field.

Safe copy angle:

- "A compact toolbar keeps copy, paste, clear, settings, and clipboard tools within reach."

### 11. Clear Text Field

SweetKeyboard can attempt to clear the active field from the toolbar.

Behavior:

- Deletes selected text when exposed by the host app
- Attempts to move through exposed text context and delete in batches
- Usually immediate in short fields
- Best effort in long documents or apps that expose limited text context to keyboard extensions

Why it matters:

- Useful for forms, search fields, prompts, notes, and short text fields.

Safe copy angle:

- "Clear short fields from the keyboard toolbar."
- Avoid claiming it clears every document perfectly.

## Priority 3: Settings, App Shell, And Supporting Experience

These are useful context for screenshots, onboarding, support copy, and secondary App Store text.

### 12. Containing App

The main app is a setup, settings, education, and trust surface.

Current tabs:

- Home: setup steps for adding the keyboard and enabling Full Access only if clipboard tools are desired
- Settings: shared controls for keyboard behavior and clipboard options
- Features: marketing-oriented overview of differentiators
- Info: privacy explanation, Full Access explanation, iOS limitations, app version, and public privacy policy link

The app includes:

- Keyboard setup instructions
- Shared feature toggles
- Full Access status messaging
- Privacy explanation
- Public privacy policy link
- Platform limitation notes
- Adaptive light and dark appearance

### 13. User Settings

Settings are available in the containing app and inside the keyboard extension.

Current shared settings:

- Clipboard Toolbar
- Open Clipboard After Copy
- Native iPhone Clipboard Buttons
- Auto-capitalization
- Forward delete with Shift
- Swipe cursor
- Key haptics

Symbol lock is controlled directly from the symbols and emoji layout and persists through shared settings.

Default behavior:

- Clipboard mode: off
- Key haptics: off
- Auto-capitalization: on
- Symbol lock: off
- Open Clipboard After Copy: off
- Native iPhone Clipboard Buttons: Import and Paste
- Swipe cursor: on
- Forward delete with Shift: off

### 14. Optional Haptics

SweetKeyboard supports optional light haptic feedback for supported keys and actions.

Safe copy angle:

- "Optional haptics make supported keys feel more responsive."

### 15. Forward Delete With Shift

When enabled, one-shot manual Shift can make Delete remove the character after the cursor.

Important detail:

- This is tied to manual one-shot Shift behavior, not automatic capitalization or caps lock.

Safe copy angle:

- "Turn on forward delete, then use manual Shift to delete ahead of the cursor."

## Privacy And Permission Positioning

### Without Full Access

Basic typing remains available:

- Letters
- Numbers
- Symbols
- Emoji
- Action key
- Auto-capitalization
- Accent variants

Clipboard toolbar features are unavailable without Full Access.

### With Full Access

Full Access enables optional clipboard-related features:

- Clipboard toolbar
- SweetKeyboard Clipboard
- Native iPhone Clipboard actions
- Shared app-to-keyboard settings and local clipboard state

Recommended wording:

- "Basic typing works without Full Access."
- "Full Access is optional and used for clipboard tools and shared local settings."
- "Clipboard features appear only when Full Access is available and enabled by the user."

Avoid wording:

- Do not imply Full Access is required for basic typing.
- Do not imply SweetKeyboard reads the native clipboard automatically.
- Do not imply cloud backup, cross-device sync, or account-based storage.

## iOS Platform Constraints To Disclose Carefully

These are real limitations of third-party keyboard extensions and should inform support copy, review notes, and user expectations.

- Third-party keyboards are unavailable in secure text fields.
- Some apps limit or block custom keyboards.
- Host apps do not always expose enough trait information for perfect return-key matching.
- Copy depends on the host app exposing selected plain text to the keyboard extension.
- Clear Text Field is best effort because iOS may expose only part of the active text.
- Rich text attributes and list formatting are out of scope for keyboard-extension copy/paste because the keyboard API does not expose those attributes.

Recommended wording:

- "Some features depend on what the active app exposes to third-party keyboards."
- "Clear Text Field works best in short fields and may be limited in long documents."
- "Secure fields and some apps may use the system keyboard instead."

## Suggested App Store Feature Hierarchy

Recommended order for App Store description and screenshots:

1. Permanent number row
2. One-page symbols layout
3. Cursor arrows and speed-aware cursor swipe
4. Contextual typing features such as `@`, action key, and auto-capitalization
5. Long-press accents and punctuation shortcuts
6. Optional SweetKeyboard Clipboard and pinned favorites
7. Native iPhone Clipboard actions
8. Clear Text Field
9. Local-first privacy and Full Access explanation
10. Setup app and shared settings

## Suggested Short Marketing Lines

- Fast typing without layout friction
- Numbers always visible
- Symbols in one place
- Cursor movement without the magnifier
- Favorites for snippets you paste again
- Clipboard tools only if you opt in
- Private by default, local by design
- Familiar QWERTY, smarter everyday controls
- Built for quick edits, codes, forms, and repeated snippets

## Suggested Screenshot Concepts

1. Main keyboard with permanent number row
2. Symbols page with grouped symbols and punctuation
3. Cursor keys and swipe cursor setting
4. Clipboard grid with pinned favorites
5. Native iPhone Clipboard action buttons
6. App Settings showing clipboard options, auto-capitalization, swipe cursor, haptics, and forward delete
7. Info screen showing privacy and Full Access explanation

## Claims To Avoid Or Qualify

Avoid absolute or unsupported claims:

- "Works everywhere" because secure fields and some apps block third-party keyboards
- "Clears any text field instantly" because Clear Text Field is host-context dependent
- "Reads your clipboard automatically" because native clipboard access is user-triggered
- "Syncs your clipboard" because there is no cloud sync
- "Supports every language" because the current primary layout is English QWERTY
- "Full Access is required" because basic typing works without it
- "AI keyboard" because there is no remote inference or AI processing

## Technical Context For More Advanced Copy

The product is implemented as:

- A SwiftUI containing app for setup, settings, feature education, and privacy information
- A `UIInputViewController` keyboard extension
- Shared local storage through App Group `UserDefaults`
- Local clipboard persistence in the App Group
- Privacy manifests declaring no tracking and no collected data
- UserDefaults required-reason declaration for App Group storage

Current release validation already performed in the production-prep pass:

- Unit tests passed
- Static analysis passed
- Release build passed
- Local archive passed
- Privacy manifests added to both app and keyboard extension
- Public privacy policy URL is live

Use this technical context only if writing developer-facing, review-note, or trust-oriented copy. Consumer-facing copy should stay simpler and focus on the typing benefits.

## Final Copywriting Guidance

The safest overall framing is:

SweetKeyboard is a familiar, local-first iOS keyboard for users who want everyday typing to involve fewer layout switches. It keeps numbers visible, groups symbols together, adds cursor controls, and offers optional clipboard tools with pinned local snippets. Basic typing works without Full Access; clipboard features are opt-in and local to the device.

