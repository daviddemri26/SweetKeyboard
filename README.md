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
- Shift, backspace, space, and return keys
- Local clipboard history with:
  - newest first
  - max 50 items
  - max 500 characters per item
  - consecutive duplicate prevention
- Clipboard panel inside the keyboard UI
- Containing app onboarding and local debug screen
- Light and dark mode native system styling

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
├── SweetKeyboard/                  # Containing app
│   ├── ContentView.swift           # Onboarding + clipboard debug UI
│   ├── SweetKeyboardApp.swift
│   ├── Shared/                     # Shared clipboard model/store for the app
│   └── SweetKeyboard.entitlements
├── SweetKeyboardKeyboard/          # Keyboard extension
│   ├── KeyboardViewController.swift
│   ├── KeyboardLayoutEngine.swift
│   ├── KeyboardActionBarView.swift
│   ├── ClipboardPanelView.swift
│   ├── ClipboardStore.swift
│   ├── ClipboardItem.swift
│   ├── AppGroup.swift
│   ├── Info.plist
│   └── SweetKeyboardKeyboard.entitlements
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

## Known Platform Limitations

- Third-party keyboards are unavailable in secure text fields
- Some apps or input contexts may block custom keyboards
- Copy only works when selected text is exposed to the keyboard extension through `textDocumentProxy`
- System-wide passive clipboard capture is intentionally out of scope

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
- Add tests around clipboard normalization and persistence rules
- Add explicit onboarding copy for privacy and Full Access rationale

