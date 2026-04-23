import XCTest
@testable import SweetKeyboard

@MainActor
final class SharedStoreTests: XCTestCase {
    func testClipboardStoreNormalizesAndDeduplicatesConsecutiveValues() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let longText = "  " + String(repeating: "a", count: 600) + "  "

        store.add(text: longText, source: .keyboardCopy)
        store.add(text: String(repeating: "a", count: 500), source: .keyboardCopy)

        let items = store.allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.text.count, 500)
        XCTAssertEqual(items.first?.text, String(repeating: "a", count: 500))
    }

    func testClipboardStoreKeepsOnlyMostRecentFiftyItems() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)

        for index in 0..<60 {
            store.add(text: "item-\(index)", source: .keyboardCopy)
        }

        let items = store.allItems()
        XCTAssertEqual(items.count, 50)
        XCTAssertEqual(items.first?.text, "item-59")
        XCTAssertEqual(items.last?.text, "item-10")
    }

    func testSharedKeyboardSettingsStoreDefaultsClipboardModeToOff() {
        let defaults = makeDefaults()
        let store = SharedKeyboardSettingsStore(defaults: defaults)

        XCTAssertFalse(store.load().clipboardModeEnabled)
        XCTAssertFalse(store.load().keyHapticsEnabled)
        XCTAssertTrue(store.load().autoCapitalizationEnabled)
        XCTAssertFalse(store.load().symbolLockEnabled)
    }

    func testSharedKeyboardSettingsStorePersistsClipboardMode() {
        let defaults = makeDefaults()
        let store = SharedKeyboardSettingsStore(defaults: defaults)

        store.setClipboardModeEnabled(true)

        XCTAssertTrue(store.load().clipboardModeEnabled)
    }

    func testSharedKeyboardSettingsStorePersistsKeyHapticsMode() {
        let defaults = makeDefaults()
        let store = SharedKeyboardSettingsStore(defaults: defaults)

        store.setKeyHapticsEnabled(true)

        XCTAssertTrue(store.load().keyHapticsEnabled)
    }

    func testSharedKeyboardSettingsStorePersistsAutoCapitalizationMode() {
        let defaults = makeDefaults()
        let store = SharedKeyboardSettingsStore(defaults: defaults)

        store.setAutoCapitalizationEnabled(false)

        XCTAssertFalse(store.load().autoCapitalizationEnabled)
    }

    func testSharedKeyboardSettingsStorePersistsSymbolLockMode() {
        let defaults = makeDefaults()
        let store = SharedKeyboardSettingsStore(defaults: defaults)

        store.setSymbolLockEnabled(true)

        XCTAssertTrue(store.load().symbolLockEnabled)
    }

    func testSharedKeyboardSettingsStoreLoadsLegacyPayloadWithoutKeyHaptics() throws {
        let defaults = makeDefaults()
        let legacySettings = """
        {"clipboardModeEnabled":true}
        """.data(using: .utf8)!
        defaults.set(legacySettings, forKey: "keyboard.settings.v1")

        let store = SharedKeyboardSettingsStore(defaults: defaults)

        XCTAssertEqual(
            store.load(),
            SharedKeyboardSettings(
                clipboardModeEnabled: true,
                keyHapticsEnabled: false,
                autoCapitalizationEnabled: true,
                symbolLockEnabled: false
            )
        )
    }

    func testSharedKeyboardSettingsStoreLoadsPayloadWithoutSymbolLockField() throws {
        let defaults = makeDefaults()
        let payload = """
        {"clipboardModeEnabled":true,"keyHapticsEnabled":true,"autoCapitalizationEnabled":false}
        """.data(using: .utf8)!
        defaults.set(payload, forKey: "keyboard.settings.v1")

        let store = SharedKeyboardSettingsStore(defaults: defaults)

        XCTAssertEqual(
            store.load(),
            SharedKeyboardSettings(
                clipboardModeEnabled: true,
                keyHapticsEnabled: true,
                autoCapitalizationEnabled: false,
                symbolLockEnabled: false
            )
        )
    }

    func testKeyboardCapabilityStatusStoreDefaultsToNoConfirmation() {
        let defaults = makeDefaults()
        let store = KeyboardCapabilityStatusStore(defaults: defaults, fileURL: nil)

        XCTAssertNil(store.load().lastConfirmedFullAccessAt)
    }

    func testKeyboardCapabilityStatusStorePersistsConfirmationTimestamp() {
        let defaults = makeDefaults()
        let fileURL = makeCapabilityStatusFileURL()
        let store = KeyboardCapabilityStatusStore(defaults: defaults, fileURL: fileURL)
        let confirmationDate = Date(timeIntervalSince1970: 1_713_708_900)

        store.confirmFullAccessNow(at: confirmationDate)

        let reloadedStore = KeyboardCapabilityStatusStore(defaults: defaults, fileURL: fileURL)

        XCTAssertEqual(
            reloadedStore.load(),
            KeyboardCapabilityStatus(lastConfirmedFullAccessAt: confirmationDate)
        )
    }

    func testKeyboardCapabilityStatusStoreMigratesBooleanPayloadToConfirmationTimestamp() {
        let defaults = makeDefaults()
        let fileURL = makeCapabilityStatusFileURL()
        let confirmationDate = Date(timeIntervalSince1970: 1_713_708_900)
        let payload = try! JSONEncoder().encode(
            LegacyBooleanCapabilityStatus(
                isFullAccessEnabled: true,
                lastUpdatedAt: confirmationDate
            )
        )

        defaults.set(payload, forKey: "keyboard.capabilities.v1")

        let store = KeyboardCapabilityStatusStore(defaults: defaults, fileURL: fileURL)

        XCTAssertEqual(store.load().lastConfirmedFullAccessAt, confirmationDate)
    }

    func testKeyboardCapabilityStatusStoreLoadsLegacyConfirmationPayload() {
        let defaults = makeDefaults()
        let fileURL = makeCapabilityStatusFileURL()
        let confirmationDate = Date(timeIntervalSince1970: 1_713_708_900)
        let payload = try! JSONEncoder().encode(
            KeyboardCapabilityStatus(lastConfirmedFullAccessAt: confirmationDate)
        )

        defaults.set(payload, forKey: "keyboard.capabilities.v1")

        let store = KeyboardCapabilityStatusStore(defaults: defaults, fileURL: fileURL)

        XCTAssertEqual(store.load().lastConfirmedFullAccessAt, confirmationDate)
    }

    func testKeyboardCapabilityStatusStoreLoadsLocalFallbackWhenSharedStateIsUnavailable() {
        let localDefaults = makeDefaults()
        let confirmationDate = Date(timeIntervalSince1970: 1_713_708_900)
        let localStore = KeyboardCapabilityStatusStore(defaults: nil, fileURL: nil, localFallbackDefaults: localDefaults)

        localStore.confirmFullAccessNow(at: confirmationDate)

        let unavailableSharedStore = KeyboardCapabilityStatusStore(
            defaults: nil,
            fileURL: nil,
            localFallbackDefaults: localDefaults
        )

        XCTAssertEqual(
            unavailableSharedStore.load(),
            KeyboardCapabilityStatus(lastConfirmedFullAccessAt: confirmationDate)
        )
    }

    func testHistorySummaryMentionsMissingConfirmation() {
        XCTAssertEqual(
            KeyboardCapabilityStatusTextFormatter.historySummary(for: KeyboardCapabilityStatus()),
            "Full Access has never been confirmed on this device."
        )
    }

    func testHistorySummaryUsesFactualConfirmationLanguage() {
        let text = KeyboardCapabilityStatusTextFormatter.historySummary(
            for: KeyboardCapabilityStatus(lastConfirmedFullAccessAt: Date(timeIntervalSince1970: 1_713_708_900))
        )

        XCTAssertTrue(text.hasPrefix("Last confirmed on "))
    }

    func testAppSettingsSummaryExplainsSavedPreferenceWhenNeverConfirmed() {
        let text = KeyboardCapabilityStatusTextFormatter.appSettingsSummary(for: KeyboardCapabilityStatus())

        XCTAssertTrue(text.hasPrefix("Clipboard tools only appear in the keyboard when Full Access is currently available."))
        XCTAssertTrue(text.contains("\nFull Access has never been confirmed on this device."))
    }

    func testKeyboardSettingsSummaryReflectsUnavailableSavedClipboardPreference() {
        let text = KeyboardCapabilityStatusTextFormatter.keyboardSettingsSummary(
            isFullAccessCurrentlyAvailable: false,
            status: KeyboardCapabilityStatus(lastConfirmedFullAccessAt: Date(timeIntervalSince1970: 1_713_708_900)),
            isClipboardModeEnabled: true
        )

        XCTAssertEqual(text, "Please enable Full Access for SweetKeyboard in Settings app.")
    }

    func testKeyboardSettingsSummaryReflectsCurrentAvailability() {
        let text = KeyboardCapabilityStatusTextFormatter.keyboardSettingsSummary(
            isFullAccessCurrentlyAvailable: true,
            status: KeyboardCapabilityStatus(lastConfirmedFullAccessAt: Date(timeIntervalSince1970: 1_713_708_900)),
            isClipboardModeEnabled: false
        )

        XCTAssertNil(text)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeCapabilityStatusFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    private struct LegacyBooleanCapabilityStatus: Encodable {
        let isFullAccessEnabled: Bool
        let lastUpdatedAt: Date
    }
}
