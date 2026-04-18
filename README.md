# SweetKeyboard

SweetKeyboard is an iOS MVP for a custom third-party keyboard with a privacy-first clipboard workflow.

The project contains:

- A containing iOS app used for onboarding, privacy explanation, and local clipboard debug tools
- A custom keyboard extension built with `UIInputViewController`
- A shared local clipboard history stored through an App Group

## Current MVP Scope

Implemented in the current codebase:

- English QWERTY keyboard
- Extra top number row: `1 2 3 4 5 6 7 8 9 0`
- Top action bar with `Copy`, `Paste`, `Clipboard`, and `Settings`
- Globe key for keyboard switching
- Shift, backspace, space, and a contextual bottom-right action key
- Local clipboard history with:
  - newest first
  - max 50 items
  - max 500 characters per item
  - consecutive duplicate prevention
- Clipboard panel inside the keyboard UI
- Containing app onboarding and local debug screen
- Light and dark mode native system styling
- Action-key trait logging through the shared App Group for host-app testing

## Contextual Action Key

The bottom-right key resolves from the active input object's traits exposed through `textDocumentProxy`.

### Mapping Table

| `UIReturnKeyType` | UI treatment | Notes |
| --- | --- | --- |
| `default` | icon | Uses SF Symbol `return.left` with `arrow.turn.down.left` fallback |
| `search` | icon | Uses `magnifyingglass`; falls back to `Search` text if the symbol is unavailable |
| `go` | text | `Go` |
| `google` | text | `Google` |
| `join` | text | `Join` |
| `next` | text | `Next` |
| `route` | text | `Route` |
| `send` | text | `Send` |
| `yahoo` | text | `Yahoo` |
| `done` | text | `Done` |
| `emergencyCall` | text | `Emergency` visible label, `Emergency Call` accessibility label |
| `continue` | text | `Continue` |
| unknown / unavailable | default icon | Conservative fallback |

### Reliable Cases

- Fields that surface `returnKeyType` through the keyboard extension proxy
- Search bars and search fields that expose `returnKeyType.search`
- Form flows that expose `returnKeyType.next`
- Chat, compose, or submit flows that expose `send`, `done`, or `go`
- Disablement when the host sets `enablesReturnKeyAutomatically` and the field is empty

### Approximate Cases

- Matching the exact native visual treatment of every host app: third-party keyboards can mirror the intent, not the private system artwork
- Determining whether a generic `.default` field is truly multiline versus a single-line field with no special return key trait
- Search inference when a host app exposes incomplete traits: SweetKeyboard intentionally falls back to the default return icon instead of guessing
- Host-specific next/send/search behavior: the keyboard inserts `"\n"` through the proxy and relies on the host text control to interpret it as its configured return action

### Not Possible From a Third-Party Keyboard Extension

- Calling private host-app submit handlers directly
- Reliably identifying the host app or field name from the extension
- Accessing secure text fields, phone pad fields, or apps that reject custom keyboards
- Reproducing private system-only keycap artwork or inline system controls exactly

### Debugging

- The containing app shows recent action-key snapshots recorded by the extension
- Snapshots include resolved action type, display mode, `returnKeyType`, `keyboardType`, `textContentType`, and empty/non-empty state
- Snapshots intentionally exclude typed text for privacy

## Privacy Model

SweetKeyboard is intentionally local-only.

- No network calls
- No analytics
- No cloud sync
- No keystroke upload
- Clipboard history stored locally in an App Group shared container

The keyboard requests Full Access because the MVP needs:

- `UIPasteboard` integration
- shared storage between the app and the keyboard extension

Open access is enabled for platform capability reasons only, not for remote data usage.

## Project Structure

```text
SweetKeyboard/
├── Shared/                         # Shared models + persistence for both targets
├── SweetKeyboard/                  # Containing app
│   ├── ContentView.swift           # Onboarding + clipboard debug UI
│   ├── SweetKeyboardApp.swift
│   └── SweetKeyboard.entitlements
├── SweetKeyboardKeyboard/          # Keyboard extension
│   ├── KeyboardViewController.swift
│   ├── KeyboardLayoutEngine.swift
│   ├── KeyboardActionBarView.swift
│   ├── ClipboardPanelView.swift
│   ├── Info.plist
│   └── SweetKeyboardKeyboard.entitlements
├── SweetKeyboardTests/             # XCTest coverage for shared persistence rules
└── SweetKeyboard.xcodeproj
```

## Technical Notes

- Language: `Swift`
- Keyboard UI framework: `UIKit`
- Containing app UI: `SwiftUI`
- Extension base class: `UIInputViewController`
- Shared storage: `UserDefaults(suiteName:)` with App Group
- App Group identifier: `group.com.daviddemri.SweetKeyboard`
- Bundle identifiers:
  - App: `com.daviddemri.SweetKeyboard`
  - Extension: `com.daviddemri.SweetKeyboard.keyboard`

## Requirements

- Xcode 16+
- iOS deployment target currently set by the project
- An Apple Developer account configured for signing on a real device
- The App Group capability enabled for both targets

## Setup

1. Open `SweetKeyboard.xcodeproj` in Xcode.
2. Confirm signing for both targets:
   - `SweetKeyboard`
   - `SweetKeyboardKeyboard`
3. In `Signing & Capabilities`, ensure both targets use the same App Group:
   - `group.com.daviddemri.SweetKeyboard`
4. Build the `SweetKeyboard` scheme.

## Run On iPhone

Custom keyboard extensions must be tested on a real iPhone for meaningful validation.

1. Install the app on the device.
2. Open the app once.
3. Go to `Settings > General > Keyboard > Keyboards > Add New Keyboard`.
4. Add `SweetKeyboard`.
5. Open the `SweetKeyboard` keyboard entry and enable `Allow Full Access`.
6. Open any supported text field and switch to the keyboard using the Globe key.

## Simulator Build

The project currently builds from the command line with:

```bash
xcodebuild -project SweetKeyboard.xcodeproj -scheme SweetKeyboard -sdk iphonesimulator -configuration Debug build
```

Simulator builds are useful for compile validation, but custom keyboard behavior should be validated on device.

Shared persistence tests can be run from the command line with:

```bash
xcodebuild -project SweetKeyboard.xcodeproj -scheme SweetKeyboard -configuration Debug test -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SweetKeyboardTests/SharedStoreTests
```

## Known Platform Limitations

- Third-party keyboards are unavailable in secure text fields
- Some apps or input contexts may block custom keyboards
- Copy only works when selected text is exposed to the keyboard extension through `textDocumentProxy`
- System-wide passive clipboard capture is intentionally out of scope
- Host apps may not expose enough text-input traits for exact action-key matching; SweetKeyboard falls back to the default return icon in those cases

## Git Conventions

This repository includes:

- `.gitignore` for Xcode build artifacts and local user settings
- `.gitattributes` for text normalization and binary asset handling
- `.editorconfig` for consistent whitespace and line endings

Recommended workflow:

```bash
git checkout -b feature/<short-name>
git status
git add .
git commit -m "Add <focused change>"
```

Keep commits focused. Avoid committing:

- `xcuserdata`
- Derived data
- local build outputs
- machine-specific secrets or signing artifacts

## Next MVP Steps

- Improve keyboard sizing and responsiveness across device classes
- Add stronger empty/error feedback states
- Polish clipboard panel UI
- Add explicit onboarding copy for privacy and Full Access rationale
- Validate the contextual action-key matrix on a real iPhone across Mail, Messages, Safari, Notes, and common form flows
