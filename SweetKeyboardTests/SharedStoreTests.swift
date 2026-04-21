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

    func testKeyboardCapabilityStatusStoreConfirmsFullAccess() {
        let defaults = makeDefaults()
        let store = KeyboardCapabilityStatusStore(defaults: defaults)

        XCTAssertFalse(store.load().isFullAccessEnabled)
        XCTAssertNil(store.load().lastUpdatedAt)

        store.setFullAccessEnabled(true)

        XCTAssertTrue(store.load().isFullAccessEnabled)
        XCTAssertNotNil(store.load().lastUpdatedAt)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
