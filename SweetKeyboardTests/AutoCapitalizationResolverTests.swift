import UIKit
import XCTest
@testable import SweetKeyboard

@MainActor
final class AutoCapitalizationResolverTests: XCTestCase {
    private let resolver = AutoCapitalizationResolver()
    private let shiftStateMachine = KeyboardShiftStateMachine()

    func testEmptyFieldEnablesSingleLetterAutoCapitalization() {
        let decision = resolver.resolve(
            for: makeContext(
                autocapitalizationType: .sentences,
                beforeInput: ""
            )
        )

        XCTAssertEqual(decision, .singleLetter)
    }

    func testSentenceTerminatorsEnableSingleLetterAfterTrailingSpace() {
        XCTAssertEqual(
            resolver.resolve(for: makeContext(autocapitalizationType: .sentences, beforeInput: "Hello. ")),
            .singleLetter
        )
        XCTAssertEqual(
            resolver.resolve(for: makeContext(autocapitalizationType: .sentences, beforeInput: "Hello! ")),
            .singleLetter
        )
        XCTAssertEqual(
            resolver.resolve(for: makeContext(autocapitalizationType: .sentences, beforeInput: "Hello? ")),
            .singleLetter
        )
    }

    func testNewLineEnablesSingleLetterAutoCapitalization() {
        let decision = resolver.resolve(
            for: makeContext(
                autocapitalizationType: .sentences,
                beforeInput: "Hello\n"
            )
        )

        XCTAssertEqual(decision, .singleLetter)
    }

    func testCommaDoesNotEnableSentenceAutoCapitalization() {
        let decision = resolver.resolve(
            for: makeContext(
                autocapitalizationType: .sentences,
                beforeInput: "Hello, "
            )
        )

        XCTAssertEqual(decision, .off)
    }

    func testExcludedFieldTypesDisableAutoCapitalization() {
        XCTAssertEqual(
            resolver.resolve(
                for: makeContext(
                    autocapitalizationType: .sentences,
                    keyboardType: .emailAddress
                )
            ),
            .off
        )
        XCTAssertEqual(
            resolver.resolve(
                for: makeContext(
                    autocapitalizationType: .sentences,
                    keyboardType: .URL
                )
            ),
            .off
        )
        XCTAssertEqual(
            resolver.resolve(
                for: makeContext(
                    autocapitalizationType: .sentences,
                    textContentType: String(describing: UITextContentType.username)
                )
            ),
            .off
        )
    }

    func testNoneAutocapitalizationDisablesAutoCapitalization() {
        let decision = resolver.resolve(
            for: makeContext(
                autocapitalizationType: UITextAutocapitalizationType.none,
                beforeInput: ""
            )
        )

        XCTAssertEqual(decision, .off)
    }

    func testWordsAutocapitalizationEnablesSingleLetterAfterSpace() {
        let decision = resolver.resolve(
            for: makeContext(
                autocapitalizationType: .words,
                beforeInput: "hello "
            )
        )

        XCTAssertEqual(decision, .singleLetter)
    }

    func testAllCharactersAutocapitalizationUsesPersistentShift() {
        let decision = resolver.resolve(
            for: makeContext(
                autocapitalizationType: .allCharacters,
                beforeInput: "hello"
            )
        )

        XCTAssertEqual(decision, .persistent)
    }

    func testTappingShiftWhileAutoSingleIsActiveSuppressesAutoCapitalization() {
        let context = makeContext(autocapitalizationType: .sentences, beforeInput: "")

        let result = shiftStateMachine.toggledState(
            from: .autoSingle,
            lastShiftTapAt: nil,
            now: Date(timeIntervalSince1970: 1),
            doubleTapInterval: 0.35,
            autoCapitalizationContext: context
        )

        XCTAssertEqual(result.state, .off)
        XCTAssertEqual(result.suppressedAutoCapitalizationContext, context)
    }

    func testDoubleTapPromotesShiftToManualLock() {
        let result = shiftStateMachine.toggledState(
            from: .off,
            lastShiftTapAt: Date(timeIntervalSince1970: 1),
            now: Date(timeIntervalSince1970: 1.2),
            doubleTapInterval: 0.35,
            autoCapitalizationContext: makeContext()
        )

        XCTAssertEqual(result.state, .manualLocked)
        XCTAssertNil(result.lastShiftTapAt)
    }

    func testManualSingleTurnsOffAfterCharacterInsertion() {
        let newState = shiftStateMachine.stateAfterCharacterInsertion(
            from: .manualSingle,
            autoCapitalizationDecision: .off,
            isSuppressed: false
        )

        XCTAssertEqual(newState, .off)
    }

    func testAutoSingleRecalculatesAfterCharacterInsertion() {
        let newState = shiftStateMachine.stateAfterCharacterInsertion(
            from: .autoSingle,
            autoCapitalizationDecision: .off,
            isSuppressed: false
        )

        XCTAssertEqual(newState, .off)
    }

    func testForwardDeleteOnlyActivatesForManualSingleShiftWhenEnabled() {
        XCTAssertTrue(
            shiftStateMachine.shouldUseForwardDelete(
                shiftState: .manualSingle,
                isForwardDeleteWithShiftEnabled: true
            )
        )
        XCTAssertFalse(
            shiftStateMachine.shouldUseForwardDelete(
                shiftState: .manualSingle,
                isForwardDeleteWithShiftEnabled: false
            )
        )
        XCTAssertFalse(
            shiftStateMachine.shouldUseForwardDelete(
                shiftState: .autoSingle,
                isForwardDeleteWithShiftEnabled: true
            )
        )
        XCTAssertFalse(
            shiftStateMachine.shouldUseForwardDelete(
                shiftState: .autoPersistent,
                isForwardDeleteWithShiftEnabled: true
            )
        )
        XCTAssertFalse(
            shiftStateMachine.shouldUseForwardDelete(
                shiftState: .manualLocked,
                isForwardDeleteWithShiftEnabled: true
            )
        )
        XCTAssertFalse(
            shiftStateMachine.shouldUseForwardDelete(
                shiftState: .off,
                isForwardDeleteWithShiftEnabled: true
            )
        )
    }

    private func makeContext(
        isEnabled: Bool = true,
        autocapitalizationType: UITextAutocapitalizationType? = .sentences,
        keyboardType: UIKeyboardType? = .default,
        textContentType: String? = nil,
        beforeInput: String = "",
        afterInput: String = "",
        hasSelection: Bool = false
    ) -> AutoCapitalizationContext {
        AutoCapitalizationContext(
            isEnabled: isEnabled,
            autocapitalizationType: autocapitalizationType,
            keyboardType: keyboardType,
            textContentType: textContentType,
            documentContextBeforeInput: beforeInput,
            documentContextAfterInput: afterInput,
            hasSelection: hasSelection
        )
    }
}
