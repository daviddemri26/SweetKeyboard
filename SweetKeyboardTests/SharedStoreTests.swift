import XCTest
@testable import SweetKeyboard

final class SharedStoreTests: XCTestCase {
    func testClipboardStoreNormalizesAndDeduplicatesConsecutiveValues() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let longText = "  " + String(repeating: "a", count: 600) + "  "

        store.add(text: longText, source: .manualImport)
        store.add(text: String(repeating: "a", count: 500), source: .manualImport)

        let items = store.allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.text.count, 500)
        XCTAssertEqual(items.first?.text, String(repeating: "a", count: 500))
    }

    func testClipboardStoreKeepsOnlyMostRecentFiftyItems() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)

        for index in 0..<60 {
            store.add(text: "item-\(index)", source: .manualImport)
        }

        let items = store.allItems()
        XCTAssertEqual(items.count, 50)
        XCTAssertEqual(items.first?.text, "item-59")
        XCTAssertEqual(items.last?.text, "item-10")
    }

    func testActionKeyDebugStoreDeduplicatesConsecutiveSnapshotsAndClearsState() {
        let defaults = makeDefaults()
        let store = ActionKeyDebugStore(userDefaults: defaults)
        let snapshot = makeSnapshot(id: UUID(), label: "Done")

        store.record(snapshot)
        store.record(makeSnapshot(id: UUID(), label: "Done"))

        XCTAssertEqual(store.allSnapshots().count, 1)

        store.clearAll()

        XCTAssertTrue(store.allSnapshots().isEmpty)
    }

    func testActionKeyDebugStoreCapsHistoryAtFortySnapshots() {
        let defaults = makeDefaults()
        let store = ActionKeyDebugStore(userDefaults: defaults)

        for index in 0..<45 {
            store.record(makeSnapshot(id: UUID(), label: "Label-\(index)", createdAt: Date(timeIntervalSince1970: TimeInterval(index))))
        }

        let snapshots = store.allSnapshots()
        XCTAssertEqual(snapshots.count, 40)
        XCTAssertEqual(snapshots.first?.visibleLabel, "Label-44")
        XCTAssertEqual(snapshots.last?.visibleLabel, "Label-5")
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeSnapshot(id: UUID, label: String, createdAt: Date = Date()) -> ActionKeyDebugSnapshot {
        ActionKeyDebugSnapshot(
            id: id,
            createdAt: createdAt,
            actionType: "done",
            displayMode: "text",
            visibleLabel: label,
            accessibilityLabel: label,
            debugDescription: "debug-\(label)",
            returnKeyType: "done",
            keyboardType: "default",
            textContentType: nil,
            enablesReturnKeyAutomatically: nil,
            hasText: true,
            hasDocumentText: true,
            hasSelection: false,
            documentContextContainsLineBreaks: false
        )
    }
}
