import XCTest
@testable import SweetKeyboard

@MainActor
final class ClearTextFieldDeletionControllerTests: XCTestCase {
    func testClearsShortTextFromBeginning() {
        let proxy = MockClearTextDocumentProxy(text: "hello", cursorOffset: 0)
        var controller = ClearTextFieldDeletionController(maximumOperationsPerBatch: 20)

        let result = drain(&controller, proxy: proxy)

        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(proxy.text, "")
        XCTAssertEqual(proxy.cursorOffset, 0)
    }

    func testClearsShortTextFromMiddle() {
        let proxy = MockClearTextDocumentProxy(text: "hello world", cursorOffset: 5)
        var controller = ClearTextFieldDeletionController(maximumOperationsPerBatch: 20)

        let result = drain(&controller, proxy: proxy)

        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(proxy.text, "")
        XCTAssertEqual(proxy.cursorOffset, 0)
    }

    func testClearsShortTextFromEnd() {
        let proxy = MockClearTextDocumentProxy(text: "done", cursorOffset: 4)
        var controller = ClearTextFieldDeletionController(maximumOperationsPerBatch: 20)

        let result = drain(&controller, proxy: proxy)

        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(proxy.text, "")
        XCTAssertEqual(proxy.cursorOffset, 0)
    }

    func testSelectionDoesNotLimitClearToOnlySelectedText() {
        let proxy = MockClearTextDocumentProxy(
            text: "hello world",
            cursorOffset: 6,
            selectedRange: 6..<11
        )
        var controller = ClearTextFieldDeletionController(maximumOperationsPerBatch: 20)

        let result = drain(&controller, proxy: proxy)

        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(proxy.text, "")
        XCTAssertEqual(proxy.cursorOffset, 0)
    }

    func testClearsTextBeforeAndAfterCursor() {
        let proxy = MockClearTextDocumentProxy(text: "before|after", cursorOffset: 6)
        var controller = ClearTextFieldDeletionController(maximumOperationsPerBatch: 20)

        let result = drain(&controller, proxy: proxy)

        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(proxy.text, "")
        XCTAssertEqual(proxy.cursorOffset, 0)
    }

    func testClearsTruncatedContextAcrossMultipleBatches() {
        let proxy = MockClearTextDocumentProxy(
            text: "abcdefghijklmnopqrstuvwxyz",
            cursorOffset: 0,
            contextLimit: 3
        )
        var controller = ClearTextFieldDeletionController(maximumOperationsPerBatch: 4)

        let result = drain(&controller, proxy: proxy, maximumDrainCount: 20)

        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(proxy.text, "")
        XCTAssertEqual(proxy.cursorOffset, 0)
    }

    func testEmptyFieldCompletesWithoutOperations() {
        let proxy = MockClearTextDocumentProxy(text: "", cursorOffset: 0)
        var controller = ClearTextFieldDeletionController(maximumOperationsPerBatch: 20)

        let result = controller.performNextBatch(on: proxy)

        XCTAssertEqual(result, ClearTextFieldDeletionBatchResult(status: .complete, operationCount: 0))
        XCTAssertEqual(proxy.text, "")
    }

    func testNonEmptyFieldWithoutAccessibleContextStalls() {
        let proxy = MockClearTextDocumentProxy(
            text: "hidden",
            cursorOffset: 0,
            contextLimit: 0
        )
        var controller = ClearTextFieldDeletionController(maximumOperationsPerBatch: 20)

        let result = controller.performNextBatch(on: proxy)

        XCTAssertEqual(result, ClearTextFieldDeletionBatchResult(status: .stalled, operationCount: 0))
        XCTAssertEqual(proxy.text, "hidden")
    }

    private func drain(
        _ controller: inout ClearTextFieldDeletionController,
        proxy: MockClearTextDocumentProxy,
        maximumDrainCount: Int = 10
    ) -> ClearTextFieldDeletionBatchResult {
        var result = ClearTextFieldDeletionBatchResult(status: .needsAnotherBatch, operationCount: 0)

        for _ in 0..<maximumDrainCount {
            result = controller.performNextBatch(on: proxy)
            if result.status != .needsAnotherBatch {
                return result
            }
        }

        return result
    }
}

@MainActor
private final class MockClearTextDocumentProxy: ClearTextDocumentProxy {
    private var characters: [Character]
    private let contextLimit: Int
    private var selectedOffsets: Range<Int>?
    private(set) var cursorOffset: Int

    init(
        text: String,
        cursorOffset: Int,
        selectedRange: Range<Int>? = nil,
        contextLimit: Int = .max
    ) {
        self.characters = Array(text)
        self.cursorOffset = min(max(0, cursorOffset), characters.count)
        self.selectedOffsets = selectedRange
        self.contextLimit = max(0, contextLimit)
    }

    var text: String {
        String(characters)
    }

    var documentContextBeforeInput: String? {
        let lowerBound = max(0, cursorOffset - contextLimit)
        return String(characters[lowerBound..<cursorOffset])
    }

    var documentContextAfterInput: String? {
        let upperBound = min(characters.count, cursorOffset.safelyAdding(contextLimit))
        return String(characters[cursorOffset..<upperBound])
    }

    var selectedText: String? {
        guard let selectedOffsets, !selectedOffsets.isEmpty else {
            return nil
        }

        return String(characters[selectedOffsets])
    }

    var hasText: Bool {
        !characters.isEmpty
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        selectedOffsets = nil
        cursorOffset = min(max(0, cursorOffset + offset), characters.count)
    }

    func deleteBackward() {
        if let selectedOffsets, !selectedOffsets.isEmpty {
            characters.removeSubrange(selectedOffsets)
            cursorOffset = min(selectedOffsets.lowerBound, characters.count)
            self.selectedOffsets = nil
            return
        }

        guard cursorOffset > 0 else {
            return
        }

        characters.remove(at: cursorOffset - 1)
        cursorOffset -= 1
    }
}

private extension Int {
    func safelyAdding(_ value: Int) -> Int {
        let (result, didOverflow) = addingReportingOverflow(value)
        return didOverflow ? Int.max : result
    }
}
