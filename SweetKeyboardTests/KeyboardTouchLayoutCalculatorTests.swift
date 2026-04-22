import XCTest
@testable import SweetKeyboard

final class KeyboardTouchLayoutCalculatorTests: XCTestCase {
    func testRowInsetsAssignOuterEdgesToFirstAndLastRows() {
        XCTAssertEqual(
            KeyboardTouchLayoutCalculator.rowInsets(
                rowIndex: 0,
                rowCount: 5,
                visualRowSpacing: 6,
                bottomInset: 10
            ),
            KeyboardTouchRowInsets(top: 0, bottom: 3)
        )
        XCTAssertEqual(
            KeyboardTouchLayoutCalculator.rowInsets(
                rowIndex: 2,
                rowCount: 5,
                visualRowSpacing: 6,
                bottomInset: 10
            ),
            KeyboardTouchRowInsets(top: 3, bottom: 3)
        )
        XCTAssertEqual(
            KeyboardTouchLayoutCalculator.rowInsets(
                rowIndex: 4,
                rowCount: 5,
                visualRowSpacing: 6,
                bottomInset: 10
            ),
            KeyboardTouchRowInsets(top: 3, bottom: 10)
        )
    }

    func testRowFramesCoverVerticalSpaceWithoutGaps() {
        let frames = KeyboardTouchLayoutCalculator.rowFrames(
            rowCount: 5,
            keyHeight: 42,
            visualRowSpacing: 6,
            bottomInset: 10
        )

        XCTAssertEqual(frames.first?.minY, 0)
        XCTAssertEqual(frames[0].maxY, frames[1].minY)
        XCTAssertEqual(frames[1].maxY, frames[2].minY)
        XCTAssertEqual(frames[2].maxY, frames[3].minY)
        XCTAssertEqual(frames[3].maxY, frames[4].minY)
        XCTAssertEqual(frames.last?.maxY, 244)
    }

    func testTouchFramesExpandToRowEdgesAndMidpoints() {
        let visualFrames = [
            CGRect(x: 0, y: 3, width: 20, height: 42),
            CGRect(x: 26, y: 3, width: 30, height: 42),
            CGRect(x: 62, y: 3, width: 10, height: 42)
        ]

        let touchFrames = KeyboardTouchLayoutCalculator.touchFrames(
            for: visualFrames,
            in: CGRect(x: 0, y: 0, width: 80, height: 48)
        )

        XCTAssertEqual(touchFrames.count, 3)
        XCTAssertEqual(touchFrames[0], CGRect(x: 0, y: 0, width: 23, height: 48))
        XCTAssertEqual(touchFrames[1], CGRect(x: 23, y: 0, width: 36, height: 48))
        XCTAssertEqual(touchFrames[2], CGRect(x: 59, y: 0, width: 21, height: 48))
    }

    func testSingleTouchFrameFillsEntireRow() {
        let touchFrames = KeyboardTouchLayoutCalculator.touchFrames(
            for: [CGRect(x: 18, y: 3, width: 44, height: 42)],
            in: CGRect(x: 0, y: 0, width: 80, height: 48)
        )

        XCTAssertEqual(touchFrames, [CGRect(x: 0, y: 0, width: 80, height: 48)])
    }
}
