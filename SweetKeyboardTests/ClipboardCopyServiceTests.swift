import XCTest
@testable import SweetKeyboard

final class ClipboardCopyServiceTests: XCTestCase {
    func testCopySelectedTextWritesAndVerifiesExactUTF8Bytes() {
        let pasteboard = MockPasteboard()
        let service = ClipboardCopyService()
        let text = """
          leading spaces\tand tabs
        bullets:
        • first item
        • second item
        numbered:
        1. one
        2. two
        CRLF:\r\nnext
        non-breaking:\u{00A0}space
        zero-width:\u{200B}end
        emoji: 👩🏽‍💻🚀︎
        RTL:\u{200F}אבג
        accents: éèêçàùñ
        math: ≠ ≤ ≥ ∞ ±
        trailing spaces  
        """

        XCTAssertTrue(service.copySelectedText(text, to: pasteboard))
        XCTAssertEqual(pasteboard.storedStringUTF8Bytes, Array(text.utf8))
    }

    func testCopySelectedTextRejectsReadBackWithDifferentBytes() {
        let composed = "\u{00E9}"
        let decomposed = "e\u{0301}"
        let pasteboard = MockPasteboard(readOverride: decomposed)
        let service = ClipboardCopyService()

        XCTAssertFalse(service.copySelectedText(composed, to: pasteboard))
        XCTAssertNotEqual(Array(composed.utf8), Array(decomposed.utf8))
    }

    func testCopySelectedTextRejectsEmptyText() {
        let pasteboard = MockPasteboard()
        let service = ClipboardCopyService()

        XCTAssertFalse(service.copySelectedText("", to: pasteboard))
        XCTAssertNil(pasteboard.storedString)
    }

    func testSystemImportAvailabilityChecksWithoutReadingPasteboardText() {
        let defaults = makeDefaults()
        let pasteboard = MockReadablePasteboard(changeCount: 10, hasStrings: true, string: "copied text")
        let service = ClipboardSystemImportService(defaults: defaults)

        XCTAssertTrue(service.hasAvailableText(in: pasteboard, context: enabledContext))
        XCTAssertEqual(pasteboard.stringReadCount, 0)
    }

    func testSystemImportStoresNewPlainTextOncePerPasteboardChangeCount() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let pasteboard = MockReadablePasteboard(changeCount: 10, hasStrings: true, string: "copied text")
        let service = ClipboardSystemImportService(defaults: defaults)

        XCTAssertEqual(service.importAvailableText(from: pasteboard, into: store, context: enabledContext), .stored)
        XCTAssertEqual(service.importAvailableText(from: pasteboard, into: store, context: enabledContext), .alreadyProcessed)
        XCTAssertFalse(service.hasAvailableText(in: pasteboard, context: enabledContext))

        XCTAssertEqual(store.allItems().map(\.text), ["copied text"])
        XCTAssertEqual(store.allItems().first?.source, .systemPasteboardImport)
    }

    func testSystemImportMarkProcessedHidesAvailabilityWithoutReadingText() {
        let defaults = makeDefaults()
        let pasteboard = MockReadablePasteboard(changeCount: 15, hasStrings: true, string: "copied text")
        let service = ClipboardSystemImportService(defaults: defaults)

        service.markProcessed(pasteboard)

        XCTAssertFalse(service.hasAvailableText(in: pasteboard, context: enabledContext))
        XCTAssertEqual(pasteboard.stringReadCount, 0)
    }

    func testSystemImportSkipsUnavailableContextsWithoutReadingPasteboardText() {
        let contexts = [
            ClipboardSystemImportContext(
                isFullAccessAvailable: false,
                isClipboardModeEnabled: true
            ),
            ClipboardSystemImportContext(
                isFullAccessAvailable: true,
                isClipboardModeEnabled: false
            )
        ]

        for context in contexts {
            let defaults = makeDefaults()
            let store = ClipboardStore(defaults: defaults)
            let pasteboard = MockReadablePasteboard(changeCount: 20, hasStrings: true, string: "copied text")
            let service = ClipboardSystemImportService(defaults: defaults)

            XCTAssertFalse(service.hasAvailableText(in: pasteboard, context: context))
            XCTAssertEqual(service.importAvailableText(from: pasteboard, into: store, context: context), .unavailable)
            XCTAssertEqual(pasteboard.stringReadCount, 0)
            XCTAssertTrue(store.allItems().isEmpty)
        }
    }

    func testSystemImportSkipsPasteboardsWithoutTextWithoutReadingString() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let pasteboard = MockReadablePasteboard(changeCount: 30, hasStrings: false, string: "hidden")
        let service = ClipboardSystemImportService(defaults: defaults)

        XCTAssertFalse(service.hasAvailableText(in: pasteboard, context: enabledContext))
        XCTAssertEqual(service.importAvailableText(from: pasteboard, into: store, context: enabledContext), .noText)
        XCTAssertEqual(service.importAvailableText(from: pasteboard, into: store, context: enabledContext), .alreadyProcessed)

        XCTAssertEqual(pasteboard.stringReadCount, 0)
        XCTAssertTrue(store.allItems().isEmpty)
    }

    func testSystemImportSkipsEmptyStrings() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let pasteboard = MockReadablePasteboard(changeCount: 40, hasStrings: true, string: "")
        let service = ClipboardSystemImportService(defaults: defaults)

        XCTAssertTrue(service.hasAvailableText(in: pasteboard, context: enabledContext))
        XCTAssertEqual(service.importAvailableText(from: pasteboard, into: store, context: enabledContext), .emptyText)

        XCTAssertEqual(pasteboard.stringReadCount, 1)
        XCTAssertTrue(store.allItems().isEmpty)
    }

    func testSystemImportPreservesUTF8BytesExactly() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let text = "  \nTabs\tCRLF\r\nemoji 👩🏽‍💻 zero-width\u{200B} accent e\u{0301}  "
        let pasteboard = MockReadablePasteboard(changeCount: 50, hasStrings: true, string: text)
        let service = ClipboardSystemImportService(defaults: defaults)

        XCTAssertEqual(service.importAvailableText(from: pasteboard, into: store, context: enabledContext), .stored)

        XCTAssertEqual(store.allItems().first?.text, text)
        XCTAssertEqual(store.allItems().first.map { Array($0.text.utf8) }, Array(text.utf8))
    }

    func testSystemImportDeduplicatesConsecutiveClipboardValues() {
        let defaults = makeDefaults()
        let store = ClipboardStore(defaults: defaults)
        let pasteboard = MockReadablePasteboard(changeCount: 60, hasStrings: true, string: "same")
        let service = ClipboardSystemImportService(defaults: defaults)

        XCTAssertEqual(service.importAvailableText(from: pasteboard, into: store, context: enabledContext), .stored)

        pasteboard.changeCount = 61
        XCTAssertEqual(service.importAvailableText(from: pasteboard, into: store, context: enabledContext), .duplicate)

        XCTAssertEqual(store.allItems().map(\.text), ["same"])
    }

    private var enabledContext: ClipboardSystemImportContext {
        ClipboardSystemImportContext(
            isFullAccessAvailable: true,
            isClipboardModeEnabled: true
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private final class MockPasteboard: ClipboardTextPasteboard {
        private let readOverride: String?
        private(set) var storedString: String?

        var storedStringUTF8Bytes: [UInt8]? {
            storedString.map { Array($0.utf8) }
        }

        var string: String? {
            get { readOverride ?? storedString }
            set { storedString = newValue }
        }

        init(readOverride: String? = nil) {
            self.readOverride = readOverride
        }
    }

    private final class MockReadablePasteboard: ClipboardReadablePasteboard {
        var changeCount: Int
        let hasStrings: Bool
        private let storedString: String?
        private(set) var stringReadCount = 0

        var string: String? {
            stringReadCount += 1
            return storedString
        }

        init(changeCount: Int, hasStrings: Bool, string: String?) {
            self.changeCount = changeCount
            self.hasStrings = hasStrings
            self.storedString = string
        }
    }
}
