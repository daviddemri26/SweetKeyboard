import XCTest
@testable import SweetKeyboard

@MainActor
final class SharedStoreTests: XCTestCase {
    func testClipboardStorePreservesCopiedTextExactly() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let longText = "  " + String(repeating: "a", count: 600) + "  "

        store.add(text: longText, source: .keyboardCopy)

        let items = store.allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.text.count, longText.count)
        XCTAssertEqual(items.first?.text, longText)
    }

    func testClipboardStorePreservesSpecialCharactersExactly() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let text = "  \n" + """
        Leading spaces, tabs, and symbols:
        \t"quoted" 'single' \\ backslash / slash
        emoji: 👩🏽‍💻🚀
        accents: éèêçàùñ
        math: ≠ ≤ ≥ ∞ ±
        bullets:
        • first item
        • second item
        numbered:
        1. one
        2. two
        zero-width:\u{200B}end

        trailing spaces
        """ + "  "

        store.add(text: text, source: .keyboardCopy)

        let items = store.allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.text, text)
        XCTAssertEqual(items.first.map { Array($0.text.utf8) }, Array(text.utf8))
    }

    func testClipboardStoreTreatsCanonicallyEquivalentDifferentBytesAsDistinct() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let composed = "\u{00E9}"
        let decomposed = "e\u{0301}"

        store.add(text: composed, source: .keyboardCopy)
        store.add(text: decomposed, source: .keyboardCopy)

        let items = store.allItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first.map { Array($0.text.utf8) }, Array(decomposed.utf8))
        XCTAssertEqual(items.last.map { Array($0.text.utf8) }, Array(composed.utf8))
        XCTAssertNotEqual(Array(composed.utf8), Array(decomposed.utf8))
    }

    func testClipboardStoreDeduplicatesConsecutiveUntruncatedValues() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let longText = String(repeating: "a", count: 600)

        store.add(text: longText, source: .keyboardCopy)
        store.add(text: longText, source: .keyboardCopy)

        let items = store.allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.text, longText)
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

    func testClipboardStoreLoadsLegacyItemsAsUnpinned() throws {
        let defaults = makeDefaults()
        let legacyItem = LegacyClipboardItem(
            id: UUID(),
            text: "legacy",
            createdAt: Date(timeIntervalSince1970: 1_713_708_900),
            source: .keyboardCopy
        )
        defaults.set(try JSONEncoder().encode([legacyItem]), forKey: "clipboard.history.v1")
        let store = ClipboardStore(defaults: defaults)

        let item = try XCTUnwrap(store.allItems().first)
        XCTAssertFalse(item.isPinned)
        XCTAssertNil(item.pinnedAt)
    }

    func testClipboardStorePinsItemsBeforeUnpinnedHistory() throws {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        store.add(text: "older", source: .keyboardCopy)
        store.add(text: "newer", source: .keyboardCopy)
        let older = try XCTUnwrap(store.allItems().first { $0.text == "older" })

        XCTAssertTrue(store.setPinned(id: older.id, isPinned: true, pinnedAt: Date(timeIntervalSince1970: 10)))

        let items = store.allItems()
        XCTAssertEqual(items.map(\.text), ["older", "newer"])
        XCTAssertTrue(items[0].isPinned)
        XCTAssertEqual(items[0].pinnedAt, Date(timeIntervalSince1970: 10))
    }

    func testClipboardStoreOrdersPinnedItemsByNewestPinFirst() throws {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        store.add(text: "first", source: .keyboardCopy)
        store.add(text: "second", source: .keyboardCopy)
        store.add(text: "third", source: .keyboardCopy)
        let first = try XCTUnwrap(store.allItems().first { $0.text == "first" })
        let second = try XCTUnwrap(store.allItems().first { $0.text == "second" })

        XCTAssertTrue(store.setPinned(id: first.id, isPinned: true, pinnedAt: Date(timeIntervalSince1970: 10)))
        XCTAssertTrue(store.setPinned(id: second.id, isPinned: true, pinnedAt: Date(timeIntervalSince1970: 20)))

        XCTAssertEqual(store.allItems().map(\.text), ["second", "first", "third"])
    }

    func testClipboardStoreUnpinsItems() throws {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        store.add(text: "unpinned", source: .keyboardCopy)
        store.add(text: "pinned", source: .keyboardCopy)
        let item = try XCTUnwrap(store.allItems().first { $0.text == "pinned" })

        XCTAssertTrue(store.setPinned(id: item.id, isPinned: true, pinnedAt: Date(timeIntervalSince1970: 10)))
        XCTAssertTrue(store.setPinned(id: item.id, isPinned: false))

        let updatedItem = try XCTUnwrap(store.allItems().first { $0.id == item.id })
        XCTAssertFalse(updatedItem.isPinned)
        XCTAssertNil(updatedItem.pinnedAt)
    }

    func testClipboardStoreDeletesItemsByID() throws {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        store.add(text: "kept", source: .keyboardCopy)
        store.add(text: "deleted", source: .keyboardCopy)
        let deletedItem = try XCTUnwrap(store.allItems().first { $0.text == "deleted" })

        XCTAssertTrue(store.delete(id: deletedItem.id))

        XCTAssertEqual(store.allItems().map(\.text), ["kept"])
        XCTAssertFalse(store.delete(id: deletedItem.id))
    }

    func testSharedKeyboardSettingsStoreDefaultsClipboardModeToOff() {
        let defaults = makeDefaults()
        let store = SharedKeyboardSettingsStore(defaults: defaults)

        XCTAssertFalse(store.load().clipboardModeEnabled)
        XCTAssertFalse(store.load().keyHapticsEnabled)
        XCTAssertTrue(store.load().autoCapitalizationEnabled)
        XCTAssertFalse(store.load().symbolLockEnabled)
        XCTAssertFalse(store.load().openClipboardAfterCopyEnabled)
        XCTAssertTrue(store.load().cursorSwipeEnabled)
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

    func testSharedKeyboardSettingsStorePersistsOpenClipboardAfterCopyMode() {
        let defaults = makeDefaults()
        let store = SharedKeyboardSettingsStore(defaults: defaults)

        store.setOpenClipboardAfterCopyEnabled(true)

        XCTAssertTrue(store.load().openClipboardAfterCopyEnabled)
    }

    func testSharedKeyboardSettingsStorePersistsCursorSwipeMode() {
        let defaults = makeDefaults()
        let store = SharedKeyboardSettingsStore(defaults: defaults)

        store.setCursorSwipeEnabled(false)

        XCTAssertFalse(store.load().cursorSwipeEnabled)
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
                symbolLockEnabled: false,
                openClipboardAfterCopyEnabled: false,
                cursorSwipeEnabled: true
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
                symbolLockEnabled: false,
                openClipboardAfterCopyEnabled: false,
                cursorSwipeEnabled: true
            )
        )
    }

    func testSharedKeyboardSettingsStoreLoadsPayloadWithOpenClipboardAfterCopyField() throws {
        let defaults = makeDefaults()
        let payload = """
        {"clipboardModeEnabled":true,"openClipboardAfterCopyEnabled":true}
        """.data(using: .utf8)!
        defaults.set(payload, forKey: "keyboard.settings.v1")

        let store = SharedKeyboardSettingsStore(defaults: defaults)

        XCTAssertEqual(
            store.load(),
            SharedKeyboardSettings(
                clipboardModeEnabled: true,
                keyHapticsEnabled: false,
                autoCapitalizationEnabled: true,
                symbolLockEnabled: false,
                openClipboardAfterCopyEnabled: true,
                cursorSwipeEnabled: true
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

    private struct LegacyClipboardItem: Encodable {
        let id: UUID
        let text: String
        let createdAt: Date
        let source: ClipboardItem.Source
    }
}
