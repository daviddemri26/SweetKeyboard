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
}
