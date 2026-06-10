# SweetKeyboard Release Checklist

Use this checklist before each App Store or TestFlight submission.

## Project State

- Confirm the working tree contains only intentional release changes.
- Keep the current minimum iOS version at `26.4` unless a separate compatibility pass is planned.
- Keep bundle identifiers unchanged until the Apple Developer account decision is final:
    - `com.daviddemri.SweetKeyboard`
    - `com.daviddemri.SweetKeyboard.keyboard`
    - `group.com.daviddemri.SweetKeyboard`
- Confirm `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` match the App Store Connect version and build number.

## Local Validation

- Run unit tests:
    - `xcodebuild test -project SweetKeyboard.xcodeproj -scheme SweetKeyboard -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`
- Run static analysis:
    - `xcodebuild analyze -project SweetKeyboard.xcodeproj -scheme SweetKeyboard -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`
- Run a Release device build:
    - `xcodebuild build -project SweetKeyboard.xcodeproj -scheme SweetKeyboard -configuration Release -destination 'generic/platform=iOS'`
- Create an archive:
    - `xcodebuild archive -project SweetKeyboard.xcodeproj -scheme SweetKeyboard -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/SweetKeyboard-release.xcarchive`

## Signing And Capabilities

- Use automatic signing while the project remains on Apple Developer team `57XAAX65VC`.
- If the account changes to a business account, update the team, App IDs, App Group, entitlements, and provisioning profiles together.
- Before upload, confirm the exported App Store archive is signed with distribution credentials.
- Confirm distribution entitlements have `get-task-allow = false`.
- Confirm both the app and keyboard extension include the App Group entitlement.
- Confirm the extension `Info.plist` still has `RequestsOpenAccess = true`.

## App Store Connect

- Set the privacy policy URL to `https://lafayette-consulting.us/sweetkeyboard/privacypolicy`.
- Complete App Privacy answers consistently with the current implementation:
    - no tracking
    - no analytics
    - no advertising data
    - no data collection by Lafayette Consulting
    - clipboard features are local and user-triggered
- Mention Full Access clearly in the review notes because clipboard tools depend on it.
- Upload screenshots that show the setup flow, settings, features, and keyboard behavior.
- Submit the first build to TestFlight before public App Review.

## Manual QA

- Install on a physical iPhone.
- Enable the keyboard with Full Access off and verify basic typing still works.
- Enable Full Access and verify clipboard tools appear.
- Test letters, symbols, emoji, long-press accents, symbol lock, cursor keys, and swipe cursor movement.
- Test Copy, native iPhone Clipboard actions, SweetKeyboard Clipboard, pinned favorites, paste, and Clear Text Field.
- Test light mode, dark mode, portrait, landscape, and iPad if iPad remains supported.
- Confirm secure fields and apps that block custom keyboards fail gracefully.

## Cloudflare Static Privacy Page

- Deploy `site/sweetkeyboard/privacypolicy/index.html` to Cloudflare Pages or another static host.
- Route it to `https://lafayette-consulting.us/sweetkeyboard/privacypolicy`.
- Configure `privacy@lafayette-consulting.us` through Cloudflare Email Routing or an equivalent mailbox.
- Verify the page loads without scripts, analytics, redirects, or authentication.
