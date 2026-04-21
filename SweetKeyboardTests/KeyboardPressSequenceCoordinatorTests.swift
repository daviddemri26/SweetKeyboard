import XCTest
@testable import SweetKeyboard

@MainActor
final class KeyboardPressSequenceCoordinatorTests: XCTestCase {
    func testSymbolsCharacterInsertionReturnsToLetterKeyboard() {
        XCTAssertTrue(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .characterInsertion,
                currentLayout: .symbols,
                isSymbolLockEnabled: false
            )
        )
    }

    func testSymbolsCharacterInsertionStaysOnSymbolsWhenLockEnabled() {
        XCTAssertFalse(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .characterInsertion,
                currentLayout: .symbols,
                isSymbolLockEnabled: true
            )
        )
    }

    func testSymbolsSettingsReturnsToLetterKeyboard() {
        XCTAssertTrue(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .settings,
                currentLayout: .symbols,
                isSymbolLockEnabled: true
            )
        )
    }

    func testEmojiSettingsReturnsToLetterKeyboard() {
        XCTAssertTrue(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .settings,
                currentLayout: .emoji,
                isSymbolLockEnabled: true
            )
        )
    }

    func testSymbolsNonClosingActionsStayOnSymbolsKeyboard() {
        XCTAssertFalse(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .space,
                currentLayout: .symbols,
                isSymbolLockEnabled: false
            )
        )
        XCTAssertFalse(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .backspace,
                currentLayout: .symbols,
                isSymbolLockEnabled: false
            )
        )
        XCTAssertFalse(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .cursorMovement,
                currentLayout: .symbols,
                isSymbolLockEnabled: false
            )
        )
        XCTAssertFalse(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .primaryAction,
                currentLayout: .symbols,
                isSymbolLockEnabled: false
            )
        )
    }

    func testEmojiCharacterInsertionMatchesSymbolsLockBehavior() {
        XCTAssertTrue(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .characterInsertion,
                currentLayout: .emoji,
                isSymbolLockEnabled: false
            )
        )
        XCTAssertFalse(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .characterInsertion,
                currentLayout: .emoji,
                isSymbolLockEnabled: true
            )
        )
    }

    func testEmojiNonClosingActionsStayOnEmojiKeyboard() {
        XCTAssertFalse(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .space,
                currentLayout: .emoji,
                isSymbolLockEnabled: false
            )
        )
        XCTAssertFalse(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .backspace,
                currentLayout: .emoji,
                isSymbolLockEnabled: false
            )
        )
        XCTAssertFalse(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .cursorMovement,
                currentLayout: .emoji,
                isSymbolLockEnabled: false
            )
        )
        XCTAssertFalse(
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                .primaryAction,
                currentLayout: .emoji,
                isSymbolLockEnabled: false
            )
        )
    }

    func testOverlappingTextTouchesCommitInPressOrder() {
        var coordinator = KeyboardPressSequenceCoordinator()
        let firstKey = NSObject()
        let secondKey = NSObject()

        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: firstKey), kind: .text("A")),
            []
        )
        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: secondKey), kind: .text("B")),
            [.insertText("A")]
        )
        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: secondKey)),
            [.insertText("B")]
        )
        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: firstKey)),
            []
        )
    }

    func testShiftRemainsPendingUntilReleaseAfterTextCommit() {
        var coordinator = KeyboardPressSequenceCoordinator()
        let textKey = NSObject()
        let shiftKey = NSObject()

        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: textKey), kind: .text("a")),
            []
        )
        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: shiftKey), kind: .shift),
            [.insertText("a")]
        )
        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: shiftKey)),
            [.toggleShift]
        )
    }

    func testPendingShiftCommitsBeforeNextTextTouch() {
        var coordinator = KeyboardPressSequenceCoordinator()
        let firstKey = NSObject()
        let shiftKey = NSObject()
        let secondKey = NSObject()

        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: firstKey), kind: .text("a")),
            []
        )
        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: shiftKey), kind: .shift),
            [.insertText("a")]
        )
        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: secondKey), kind: .text("C")),
            [.toggleShift]
        )
        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: secondKey)),
            [.insertText("C")]
        )
        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: shiftKey)),
            []
        )
    }

    func testPendingLayoutSwitchCommitsOnRelease() {
        var coordinator = KeyboardPressSequenceCoordinator()
        let textKey = NSObject()
        let layoutKey = NSObject()

        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: textKey), kind: .text("a")),
            []
        )
        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: layoutKey), kind: .layoutSwitch(.symbols)),
            [.insertText("a")]
        )
        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: layoutKey)),
            [.setKeyboardLayout(.symbols)]
        )
    }

    func testPendingEmojiLayoutSwitchCommitsOnRelease() {
        var coordinator = KeyboardPressSequenceCoordinator()
        let textKey = NSObject()
        let layoutKey = NSObject()

        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: textKey), kind: .text("a")),
            []
        )
        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: layoutKey), kind: .layoutSwitch(.emoji)),
            [.insertText("a")]
        )
        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: layoutKey)),
            [.setKeyboardLayout(.emoji)]
        )
    }

    func testPendingPrimaryActionCommitsOnRelease() {
        var coordinator = KeyboardPressSequenceCoordinator()
        let textKey = NSObject()
        let actionKey = NSObject()

        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: textKey), kind: .text("a")),
            []
        )
        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: actionKey), kind: .primaryAction),
            [.insertText("a")]
        )
        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: actionKey)),
            [.insertPrimaryAction]
        )
    }

    func testCancellingPendingShiftProducesNoEffect() {
        var coordinator = KeyboardPressSequenceCoordinator()
        let shiftKey = NSObject()

        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: shiftKey), kind: .shift),
            []
        )

        coordinator.handleTouchCancelled(id: keyID(for: shiftKey))

        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: shiftKey)),
            []
        )
    }

    func testCancellingPendingLayoutSwitchProducesNoEffect() {
        var coordinator = KeyboardPressSequenceCoordinator()
        let layoutKey = NSObject()

        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: layoutKey), kind: .layoutSwitch(.symbols)),
            []
        )

        coordinator.handleTouchCancelled(id: keyID(for: layoutKey))

        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: layoutKey)),
            []
        )
    }

    func testCancellingPendingEmojiLayoutSwitchProducesNoEffect() {
        var coordinator = KeyboardPressSequenceCoordinator()
        let layoutKey = NSObject()

        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: layoutKey), kind: .layoutSwitch(.emoji)),
            []
        )

        coordinator.handleTouchCancelled(id: keyID(for: layoutKey))

        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: layoutKey)),
            []
        )
    }

    func testAlreadyCommittedTouchDoesNotCommitTwiceOnRelease() {
        var coordinator = KeyboardPressSequenceCoordinator()
        let firstKey = NSObject()
        let secondKey = NSObject()

        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: firstKey), kind: .text("A")),
            []
        )
        XCTAssertEqual(
            coordinator.handleTouchDown(id: keyID(for: secondKey), kind: .text("B")),
            [.insertText("A")]
        )

        coordinator.handleTouchCancelled(id: keyID(for: firstKey))

        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: firstKey)),
            []
        )
        XCTAssertEqual(
            coordinator.handleTouchUpInside(id: keyID(for: secondKey)),
            [.insertText("B")]
        )
    }

    private func keyID(for object: NSObject) -> ObjectIdentifier {
        ObjectIdentifier(object)
    }
}
